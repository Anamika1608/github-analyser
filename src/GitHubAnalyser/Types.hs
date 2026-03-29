{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module GitHubAnalyser.Types (
    Commit (..),
    CommitSnapshot (..),
    Event (..),
    IngestManifest (..),
    Repo (..),
    buildManifest,
    topReposForCommitFetch,
) where

import Data.Aeson
import Data.Int (Int64)
import qualified Data.List as L
import Data.Maybe (isJust)
import Data.Ord (Down (..), comparing)
import qualified Data.Text as T
import Data.Time.Clock (UTCTime)
import GHC.Generics (Generic)
import GitHubAnalyser.Config (AppConfig (..))
import GitHubAnalyser.Paths (rawEventsPath, rawReposPath)

data Repo = Repo
    { repoId :: !Int64
    , repoName :: !T.Text
    , fullName :: !T.Text
    , language :: !(Maybe T.Text)
    , createdAt :: !UTCTime
    , updatedAt :: !UTCTime
    , pushedAt :: !(Maybe UTCTime)
    , defaultBranch :: !T.Text
    , stargazersCount :: !Int
    , watchersCount :: !Int
    , forksCount :: !Int
    , openIssuesCount :: !Int
    , sizeKb :: !Int
    , archived :: !Bool
    , disabled :: !Bool
    , isFork :: !Bool
    }
    deriving (Eq, Show, Generic)

instance FromJSON Repo where
    parseJSON = withObject "Repo" $ \o ->
        Repo
            <$> o .: "id"
            <*> o .: "name"
            <*> o .: "full_name"
            <*> o .:? "language"
            <*> o .: "created_at"
            <*> o .: "updated_at"
            <*> o .:? "pushed_at"
            <*> o .: "default_branch"
            <*> o .: "stargazers_count"
            <*> o .: "watchers_count"
            <*> o .: "forks_count"
            <*> o .: "open_issues_count"
            <*> o .: "size"
            <*> o .: "archived"
            <*> o .: "disabled"
            <*> o .: "fork"

instance ToJSON Repo

data Event = Event
    { eventId :: !T.Text
    , eventType :: !T.Text
    , eventRepoName :: !T.Text
    , actorLogin :: !T.Text
    , eventCreatedAt :: !UTCTime
    , isPublic :: !Bool
    }
    deriving (Eq, Show, Generic)

instance FromJSON Event where
    parseJSON = withObject "Event" $ \o -> do
        repoObject <- o .: "repo"
        actorObject <- o .: "actor"
        Event
            <$> o .: "id"
            <*> o .: "type"
            <*> repoObject .: "name"
            <*> actorObject .: "login"
            <*> o .: "created_at"
            <*> o .: "public"

instance ToJSON Event

data Commit = Commit
    { commitRepoName :: !T.Text
    , sha :: !T.Text
    , authorLogin :: !(Maybe T.Text)
    , authorName :: !(Maybe T.Text)
    , authoredAt :: !UTCTime
    , committedAt :: !UTCTime
    , messageTitle :: !T.Text
    , parentCount :: !Int
    , isMergeCommit :: !Bool
    }
    deriving (Eq, Show, Generic)

instance ToJSON Commit

data CommitSnapshot = CommitSnapshot
    { commitSnapshotRepoName :: !T.Text
    , commitCount :: !Int
    , rawPath :: !FilePath
    }
    deriving (Eq, Show, Generic)

instance ToJSON CommitSnapshot

data IngestManifest = IngestManifest
    { manifestUser :: !T.Text
    , manifestCommitSince :: !UTCTime
    , manifestReposPath :: !FilePath
    , manifestEventsPath :: !FilePath
    , reposCount :: !Int
    , eventsCount :: !Int
    , topReposUsed :: ![T.Text]
    , commitSnapshots :: ![CommitSnapshot]
    }
    deriving (Eq, Show, Generic)

instance ToJSON IngestManifest

topReposForCommitFetch :: AppConfig -> [Repo] -> [Repo]
topReposForCommitFetch cfg =
    take (topRepoCount cfg)
        . filter (isJust . pushedAt)
        . L.sortBy (comparing (Down . pushedAt))

buildManifest :: AppConfig -> [Repo] -> [Event] -> [CommitSnapshot] -> IngestManifest
buildManifest cfg repos events snapshots =
    IngestManifest
        { manifestUser = targetUser cfg
        , manifestCommitSince = commitSince cfg
        , manifestReposPath = rawReposPath cfg
        , manifestEventsPath = rawEventsPath cfg
        , reposCount = length repos
        , eventsCount = length events
        , topReposUsed = map commitSnapshotRepoName snapshots
        , commitSnapshots = snapshots
        }
