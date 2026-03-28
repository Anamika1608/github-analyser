{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module GitHubAnalyser.GitHub (
    fetchCommitSnapshots,
    fetchEvents,
    fetchEventsSnapshot,
    fetchRepos,
    fetchReposSnapshot,
    writeManifest,
) where

import Control.Monad (forM, unless)
import Data.Aeson
import qualified Data.ByteString.Char8 as BS8
import qualified Data.ByteString.Lazy as LBS
import qualified Data.Text as T
import Data.Time.Clock (UTCTime)
import Data.Time.Format.ISO8601 (iso8601Show)
import GitHubAnalyser.Config (AppConfig (..))
import GitHubAnalyser.Paths
import GitHubAnalyser.Types
import Network.HTTP.Simple
import System.IO.Error (ioError, userError)

data PagedCollection a = PagedCollection
    { rawItems :: [Value]
    , typedItems :: [a]
    }

data GitHubCommitItem = GitHubCommitItem
    { commitSha :: !T.Text
    , commitAuthorLogin :: !(Maybe T.Text)
    , commitAuthorName :: !(Maybe T.Text)
    , commitAuthoredAt :: !UTCTime
    , commitCommittedAt :: !UTCTime
    , commitMessage :: !T.Text
    , commitParentCount :: !Int
    }

instance FromJSON GitHubCommitItem where
    parseJSON = withObject "GitHubCommitItem" $ \o -> do
        commitObject <- o .: "commit"
        committerObject <- commitObject .: "committer"
        authorObject <- commitObject .:? "author"
        parents <- o .: "parents" :: Parser [Value]
        githubAuthor <- o .:? "author"
        login <- traverse (.: "login") githubAuthor
        authoredAt <-
            case authorObject of
                Just authorDetails -> authorDetails .: "date"
                Nothing -> committerObject .: "date"
        GitHubCommitItem
            <$> o .: "sha"
            <*> pure login
            <*> case authorObject of
                Just authorDetails -> authorDetails .:? "name"
                Nothing -> pure Nothing
            <*> pure authoredAt
            <*> committerObject .: "date"
            <*> commitObject .: "message"
            <*> pure (length parents)

fetchRepos :: AppConfig -> IO [Repo]
fetchRepos cfg = typedItems <$> fetchReposCollection cfg

fetchEvents :: AppConfig -> IO [Event]
fetchEvents cfg = typedItems <$> fetchEventsCollection cfg

fetchReposSnapshot :: AppConfig -> IO [Repo]
fetchReposSnapshot cfg = do
    collection <- fetchReposCollection cfg
    writeRawArray (rawReposPath cfg) (rawItems collection)
    pure (typedItems collection)

fetchEventsSnapshot :: AppConfig -> IO [Event]
fetchEventsSnapshot cfg = do
    collection <- fetchEventsCollection cfg
    writeRawArray (rawEventsPath cfg) (rawItems collection)
    pure (typedItems collection)

fetchCommitSnapshots :: AppConfig -> [Repo] -> IO [CommitSnapshot]
fetchCommitSnapshots cfg repos =
    forM repos $ \repo -> do
        collection <- fetchCommitCollection cfg repo
        let path = rawCommitSnapshotPath cfg (repoName repo)
        writeRawArray path (rawItems collection)
        pure
            CommitSnapshot
                { commitSnapshotRepoName = repoName repo
                , commitCount = length (typedItems collection)
                , rawPath = path
                }

writeManifest :: AppConfig -> IngestManifest -> IO ()
writeManifest cfg manifest =
    LBS.writeFile (rawManifestPath cfg) (encode manifest)

fetchReposCollection :: AppConfig -> IO (PagedCollection Repo)
fetchReposCollection cfg =
    fetchPagedCollection
        cfg
        ("https://api.github.com/users/" ++ T.unpack (targetUser cfg) ++ "/repos")
        [ ("type", "owner")
        , ("sort", "updated")
        ]

fetchEventsCollection :: AppConfig -> IO (PagedCollection Event)
fetchEventsCollection cfg =
    fetchPagedCollection
        cfg
        ("https://api.github.com/users/" ++ T.unpack (targetUser cfg) ++ "/events/public")
        []

fetchCommitCollection :: AppConfig -> Repo -> IO (PagedCollection Commit)
fetchCommitCollection cfg repo = do
    collection <-
        fetchPagedCollection
            cfg
            ( "https://api.github.com/repos/"
                ++ T.unpack (targetUser cfg)
                ++ "/"
                ++ T.unpack (repoName repo)
                ++ "/commits"
            )
            [ ("author", T.unpack (targetUser cfg))
            , ("since", iso8601Show (commitSince cfg))
            ]
    pure
        PagedCollection
            { rawItems = rawItems collection
            , typedItems =
                map (toCommitRecord (repoName repo)) (typedItems collection :: [GitHubCommitItem])
            }

fetchPagedCollection ::
    FromJSON a =>
    AppConfig ->
    String ->
    [(String, String)] ->
    IO (PagedCollection a)
fetchPagedCollection cfg url extraParams = go 1 [] []
  where
    go page rawPages typedPages = do
        req <- buildRequest cfg url (pageParams page)
        response <- httpBS req
        let status = getResponseStatusCode response
        unless (status == 200) $
            ioError . userError $
                "GitHub API returned status "
                    ++ show status
                    ++ " for "
                    ++ url
                    ++ " with body: "
                    ++ BS8.unpack (getResponseBody response)

        let body = getResponseBody response
        rawPage <- decodeBody body
        typedPage <- decodeBody body
        if null typedPage
            then pure
                PagedCollection
                    { rawItems = concat (reverse rawPages)
                    , typedItems = concat (reverse typedPages)
                    }
            else go (page + 1) (rawPage : rawPages) (typedPage : typedPages)

    pageParams page =
        extraParams
            ++ [ ("per_page", "100")
               , ("page", show page)
               ]

buildRequest :: AppConfig -> String -> [(String, String)] -> IO Request
buildRequest AppConfig{..} url queryParams = do
    req0 <- parseRequest url
    let req1 =
            addToRequestQueryString
                (map (\(k, v) -> (BS8.pack k, Just (BS8.pack v))) queryParams)
                req0
    let req2 = setRequestHeader "Accept" ["application/vnd.github+json"] req1
    let req3 = setRequestHeader "User-Agent" ["github-analyser"] req2
    pure $
        case githubToken of
            Nothing -> req3
            Just token -> setRequestHeader "Authorization" ["Bearer " <> BS8.pack (T.unpack token)] req3

decodeBody :: FromJSON a => BS8.ByteString -> IO a
decodeBody body =
    case eitherDecodeStrict' body of
        Left err -> ioError (userError ("Failed to decode GitHub response: " ++ err))
        Right value -> pure value

writeRawArray :: FilePath -> [Value] -> IO ()
writeRawArray path values =
    LBS.writeFile path (encode values)

toCommitRecord :: T.Text -> GitHubCommitItem -> Commit
toCommitRecord repoName' GitHubCommitItem{..} =
    Commit
        { commitRepoName = repoName'
        , sha = commitSha
        , authorLogin = commitAuthorLogin
        , authorName = commitAuthorName
        , authoredAt = commitAuthoredAt
        , committedAt = commitCommittedAt
        , messageTitle = firstLine commitMessage
        , parentCount = commitParentCount
        , isMergeCommit = commitParentCount > 1
        }

firstLine :: T.Text -> T.Text
firstLine =
    headOrEmpty . T.lines
  where
    headOrEmpty [] = ""
    headOrEmpty (x : _) = x
