PRAGMA user_version = 12;

CREATE TABLE Authors (
    Id INTEGER PRIMARY KEY,
    DisplayName TEXT NOT NULL UNIQUE COLLATE NOCASE
) STRICT;

CREATE TABLE Articles (
    Id INTEGER PRIMARY KEY,
    AuthorId INTEGER NOT NULL REFERENCES Authors(Id) ON DELETE CASCADE,
    Slug TEXT NOT NULL COLLATE NOCASE,
    Title TEXT NOT NULL,
    Status TEXT NOT NULL DEFAULT 'draft' CHECK (Status IN ('draft', 'published', 'archived')),
    PublishedAt TEXT,
    CreatedAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (AuthorId, Slug)
) STRICT;

CREATE TABLE Tags (
    Name TEXT PRIMARY KEY COLLATE NOCASE
) STRICT;

CREATE TABLE ArticleTags (
    ArticleId INTEGER NOT NULL REFERENCES Articles(Id) ON DELETE CASCADE,
    TagName TEXT NOT NULL REFERENCES Tags(Name) ON DELETE CASCADE,
    PRIMARY KEY (ArticleId, TagName)
) WITHOUT ROWID, STRICT;

CREATE INDEX IX_Articles_AuthorCreatedAt ON Articles(AuthorId, CreatedAt);
CREATE INDEX IX_Articles_Published ON Articles(PublishedAt) WHERE Status = 'published';

CREATE VIEW PublishedArticles AS
SELECT a.Id, a.Slug, a.Title, a.PublishedAt, u.DisplayName AS Author
FROM Articles a
JOIN Authors u ON u.Id = a.AuthorId
WHERE a.Status = 'published';

CREATE TRIGGER TR_Articles_RequirePublishedAt
BEFORE UPDATE OF Status ON Articles
WHEN NEW.Status = 'published' AND NEW.PublishedAt IS NULL
BEGIN
    SELECT RAISE(ABORT, 'PublishedAt is required when publishing an article');
END;
