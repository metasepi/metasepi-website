#! /usr/bin/env runhaskell
{-# LANGUAGE OverloadedStrings #-}

import Control.Arrow
import Control.Monad (void)
import Data.Monoid

import Hakyll
import Text.Pandoc

main :: IO ()
main = hakyll $ do
  -- Tags
  void $ create "tags" $
    requireAll "posts/*" (\_ ps -> readTags ps :: Tags String)

  -- Add a tag list compiler for every tag
  match "tags/*" $ route $ setExtension ".html"
  metaCompile $ require_ "tags"
    >>> arr tagsMap
    >>> arr (map (\(t, q) -> (tagIdentifier t, makeTagList t q)))

  -- RSS
  match "rss.xml" $ route idRoute
  void $ create "rss.xml" $ requireAll_ "posts/*" >>> renderRss feedConfiguration

  -- index
  match "index.html" $ route idRoute
  void $ create "index.html" $ constA mempty
    >>> arr (setField "title" "Home")
    >>> requireA "tags" (setFieldA "tags" (renderTagList'))
    >>> setFieldPageList (take 3 . recentFirst)
          "templates/postitem.hamlet" "posts" "posts/*"
    >>> applyTemplateCompiler "templates/index.hamlet"
    >>> applyTemplateCompiler "templates/default.hamlet"

  -- pages
  void $ match (list ["about.md"]) $ do
    route $ setExtension "html"
    compile $
      pageCompilerWithPandoc
        defaultHakyllParserState
        defaultHakyllWriterOptions
        id
      >>> applyTemplateCompiler "templates/default.hamlet"
      >>> relativizeUrlsCompiler

  -- blog posts
  void $ match "posts/*.md" $ do
    route $ setExtension "html"
    compile $
      pageCompilerWithPandoc
        defaultHakyllParserState
        defaultHakyllWriterOptions { writerHTMLMathMethod = MathJax "http://cdn.mathjax.org/mathjax/latest/MathJax.js" }
        id
      >>> arr (renderDateField "date" "%Y/%m/%e" "Date unknown")
      >>> arr (renderDateField "d_year" "%Y" "Date unknown")
      >>> arr (renderDateField "d_month" "%b" "Date unknown")
      >>> arr (renderDateField "d_date" "%e" "Date unknown")
      >>> renderTagsField "prettytags" (fromCapture "tags/*")
      >>> applyTemplateCompiler "templates/post.hamlet"
      >>> applyTemplateCompiler "templates/default.hamlet"
      >>> relativizeUrlsCompiler

  -- Post list
  match "posts.html" $ route idRoute
  void $ create "posts.html" $ constA mempty
    >>> arr (setField "title" "Posts")
    >>> setFieldPageList recentFirst "templates/postitem.hamlet" "posts" "posts/*"
    >>> applyTemplateCompiler "templates/posts.hamlet"
    >>> applyTemplateCompiler "templates/default.hamlet"
    >>> relativizeUrlsCompiler

  -- templates
  void $ match "templates/*" $ compile templateCompiler

  -- static contents
  void $ match "draw/*.png" $ do
    route idRoute
    compile copyFileCompiler

  void $ match "img/**" $ do
    route idRoute
    compile copyFileCompiler

  void $ match "js/**" $ do
    route idRoute
    compile copyFileCompiler

  void $ match "css/*" $ do
    route idRoute
    compile compressCssCompiler

  match (list ["favicon.ico", "404.html", "50x.html"]) $ do
    route idRoute
    compile copyFileCompiler

  where
    renderTagList' :: Compiler (Tags String) String
    renderTagList' = renderTagList tagIdentifier

    tagIdentifier :: String -> Identifier (Page String)
    tagIdentifier = fromCapture "tags/*"

makeTagList :: String
               -> [Page String]
               -> Compiler () (Page String)
makeTagList tagg posts =
  constA posts
  >>> pageListCompiler recentFirst "templates/postitem.hamlet"
  >>> arr (copyBodyToField "posts" . fromBody)
  >>> arr (setField "title" ("Posts tagged " ++ tagg))
  >>> applyTemplateCompiler "templates/posts.hamlet"
  >>> applyTemplateCompiler "templates/default.hamlet"

feedConfiguration :: FeedConfiguration
feedConfiguration = FeedConfiguration
  { feedTitle       = "Metasepi Logbook"
  , feedDescription = "A diary to develop Metasepi kernel"
  , feedAuthorName  = "Kiwamu Okabe"
  , feedRoot        = "http://metasepi.masterq.net/"
  }
