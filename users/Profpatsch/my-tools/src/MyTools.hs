{-# LANGUAGE QuasiQuotes #-}

module MyTools where

import Control.Exception (IOException)
import Control.Exception.Base (try)
import Data.List qualified as List
import MyLabel
import MyPrelude
import Options.Applicative.Builder.Completer (requote)
import Options.Applicative.Simple (simpleOptions)
import Options.Applicative.Simple qualified as Opts
import Options.Applicative.Types qualified as Opts.Types
import System.Directory qualified as Dir
import System.Environment qualified
import System.FilePath.Posix ((</>))
import System.FilePath.Posix qualified as File
import System.Process qualified as Proc

copyMain :: IO ()
copyMain = do
  ((), run) <-
    simpleOptions
      "latest"
      "copy"
      "Various ways of copying files"
      (Opts.flag () () (Opts.long "some-flag"))
      ( do
          Opts.addCommand
            "template"
            "Use the given file as a template and create new file with the given name in the same directory"
            copyAsTemplate
            ( do
                Opts.strArgument (Opts.metavar "FILE" <> Opts.completer completeFile)
                  -- TODO: this is a hack to be able to use the file in the next argument (it leads to the argument not being in the usage message)
                  & thenParser
                    ( \file -> do
                        name <-
                          Opts.strArgument
                            ( Opts.metavar "NAME"
                                <> Opts.completer
                                  ( Opts.listCompleter
                                      [ File.takeFileName file,
                                        File.takeFileName file <> ".bak",
                                        File.takeFileName file <> "_copy"
                                      ]
                                  )
                            )
                        pure (t2 #file file #name name)
                    )
            )
      )
  run

completeFile :: Opts.Completer
completeFile = Opts.mkCompleter $ \word -> do
  isFish <- System.Environment.getEnv "SHELL" <&> ("fish" `List.isInfixOf`)

  if isFish
    then do
      let cmd =
            unwords
              [ "complete",
                "-C",
                -- loool (via the impl of __fish_complete_path), probably extremely buggy
                "\"'' " <> requote word <> "\""
              ]
      Proc.readProcess "fish" ["--private", "--no-config", "-c", cmd] "" <&> lines & try @IOException <&> hush <&> fromMaybe []
    else do
      let cmd = unwords ["compgen", "-A", "file", "--", requote word]
      Proc.readProcess "bash" ["-c", cmd] "" <&> lines & try @IOException <&> hush <&> fromMaybe []

thenParser :: (a -> Opts.Parser b) -> Opts.Parser a -> Opts.Parser b
thenParser f a = Opts.Types.BindP a f

assertMsg :: Bool -> Text -> IO ()
assertMsg b msg = unless b $ exitWithMessage msg

copyAsTemplate :: (HasField "file" r FilePath, HasField "name" r FilePath) => r -> IO ()
copyAsTemplate opts = do
  canon <- Dir.canonicalizePath opts.file
  isFile <- Dir.doesFileExist canon
  assertMsg isFile $ [fmt|File does not exist or is a directory: {canon}|]
  let dir = File.takeDirectory canon
  let finalPath = dir </> opts.name
  targetExists <- Dir.doesFileExist finalPath
  assertMsg (not targetExists) $ [fmt|Target file already exists: {finalPath}|]
  Dir.copyFile canon finalPath
