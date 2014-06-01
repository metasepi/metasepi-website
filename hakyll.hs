{-# LANGUAGE OverloadedStrings #-}

import Data.Char     (toLower)
import Data.Monoid   (mappend, mconcat)
import Hakyll
import Text.Pandoc

main :: IO ()
main = hakyll $ do
  match "css/*" $ do
    route   idRoute
    compile compressCssCompiler

  match ("img/**" .||. "js/**" .||. "doc/**" .||. "draw/*.png" .||. "plan/**" .||.
         "favicon.ico" .||. "404.html" .||. "50x.html" .||. "googlef5fb4c1f27601161.html") $ do
    route idRoute
    compile copyFileCompiler

  match (fromList ["about.md", "map.md", "docs.md", "memories.md", "past-supporters.md"]) $ do
    route   $ setExtension "html"
    compile $ pandocCompiler
      >>= loadAndApplyTemplate "templates/default.html" defaultContext
      >>= relativizeUrls

  tags <- buildTags "posts/*.md" (fromCapture "tags/*.html" . map toLower)

  match ("posts/*.md" .||. "en/posts/*.md") $ do
    route $ setExtension "html"
    compile $ pandocCompilerWith defaultHakyllReaderOptions pandocOptions
      >>= loadAndApplyTemplate "templates/post.html"    (postCtx tags)
      >>= loadAndApplyTemplate "templates/default.html" (postCtx tags)
      >>= relativizeUrls

  create ["posts.html"] $ do
        route idRoute
        compile $ do
            let archiveCtx =
                  field "posts" (\_ -> postList tags "posts/*.md" recentFirst) `mappend`
                  constField "title" "Blog posts (Japanese)"              `mappend`
                  defaultContext
            makeItem ""
                >>= loadAndApplyTemplate "templates/posts.html" archiveCtx
                >>= loadAndApplyTemplate "templates/default.html" archiveCtx
                >>= relativizeUrls

  create ["en/posts.html"] $ do
        route idRoute
        compile $ do
            let archiveCtx =
                  field "posts" (\_ -> postList tags "en/posts/*.md" recentFirst) `mappend`
                  constField "title" "Blog posts (English)"              `mappend`
                  defaultContext
            makeItem ""
                >>= loadAndApplyTemplate "templates/posts.html" archiveCtx
                >>= loadAndApplyTemplate "templates/default.html" archiveCtx
                >>= relativizeUrls

  -- Post tags
  tagsRules tags $ \tag pattern -> do
    let title = "Posts tagged " ++ tag
    -- Copied from posts, need to refactor
    route idRoute
    compile $ do
      list <- postList tags pattern recentFirst
      makeItem ""
        >>= loadAndApplyTemplate "templates/posts.html"
                (constField "title" title `mappend`
                    constField "posts" list `mappend`
                    defaultContext)
        >>= loadAndApplyTemplate "templates/default.html" defaultContext
        >>= relativizeUrls

  create ["rss.xml"] $ do
    route idRoute
    compile $ do
      let feedCtx = dateField "date" "%B %e, %Y"
                      `mappend` defaultContext
                      `mappend` constField "description" "This is the post description"
      posts <- fmap (take 10) . recentFirst =<< loadAll "posts/*"
      renderAtom (feedConfiguration {feedTitle = "Metasepi Blog (Japanese)"}) feedCtx posts

  create ["rss_en.xml"] $ do
    route idRoute
    compile $ do
      let feedCtx = dateField "date" "%B %e, %Y"
                      `mappend` defaultContext
                      `mappend` constField "description" "This is the post description"
      posts <- fmap (take 10) . recentFirst =<< loadAll "en/posts/*"
      renderAtom (feedConfiguration {feedTitle = "Metasepi Blog (English)"}) feedCtx posts

  match "index.html" $ do
    route idRoute
    compile $ do
      let indexCtxJa = field "posts_ja" $ \_ -> postList tags "posts/*.md" $ fmap (take 3) . recentFirst
          indexCtxEn = field "posts_en" $ \_ -> postList tags "en/posts/*.md" $ fmap (take 3) . recentFirst
      getResourceBody
        >>= applyAsTemplate (indexCtxJa `mappend` indexCtxEn)
        >>= loadAndApplyTemplate "templates/default.html" (postCtx tags)
        >>= relativizeUrls

  match "templates/*" $ compile templateCompiler

feedConfiguration :: FeedConfiguration
feedConfiguration = FeedConfiguration
  { feedTitle       = "Metasepi Blog"
  , feedDescription = "A diary to develop Metasepi kernel."
  , feedAuthorName  = "Kiwamu Okabe"
  , feedAuthorEmail = "kiwamu@debian.or.jp"
  , feedRoot        = "http://metasepi.org/"
  }

pandocOptions :: WriterOptions
pandocOptions = defaultHakyllWriterOptions
    { writerTableOfContents = True
    , writerTemplate = "<h2>Table of contents</h2>\n$toc$\n<hr>\n$body$"
    , writerStandalone = True
    }

--------------------------------------------------------------------------------
postCtx :: Tags -> Context String
postCtx tags = mconcat
    [ modificationTimeField "mtime" "%U"
    , dateField "date" "%B %e, %Y"
    , tagsField "tags" tags
    , defaultContext
    ]

--------------------------------------------------------------------------------
postList :: Tags -> Pattern -> ([Item String] -> Compiler [Item String]) -> Compiler String
postList tags pattern sortFilter = do
    posts   <- sortFilter =<< loadAll pattern
    itemTpl <- loadBody "templates/postitem.html"
    applyTemplateList itemTpl (postCtx tags) posts
