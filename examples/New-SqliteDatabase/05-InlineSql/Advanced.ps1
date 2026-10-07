[CmdletBinding()]
param(
    [string]$DatabasePath = (Join-Path $PSScriptRoot 'inline-sql-advanced.sqlite')
)

if (-not (Get-Module devsetup.core.sqlite)) {
    Import-Module devsetup.core.sqlite -ErrorAction Stop
}

New-SqliteDatabase -Path $DatabasePath -Query @'
CREATE TABLE Customers (
    Id INTEGER PRIMARY KEY,
    Name TEXT NOT NULL UNIQUE COLLATE NOCASE
) STRICT;

CREATE TABLE Orders (
    Id INTEGER PRIMARY KEY,
    CustomerId INTEGER NOT NULL REFERENCES Customers(Id) ON DELETE CASCADE,
    State TEXT NOT NULL DEFAULT 'new' CHECK (State IN ('new', 'paid', 'shipped', 'cancelled')),
    TotalCents INTEGER NOT NULL CHECK (TotalCents >= 0),
    CreatedAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
) STRICT;

CREATE TABLE OrderAudit (
    Id INTEGER PRIMARY KEY,
    OrderId INTEGER NOT NULL,
    PreviousState TEXT NOT NULL,
    CurrentState TEXT NOT NULL,
    ChangedAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
) STRICT;

CREATE INDEX IX_Orders_CustomerCreatedAt ON Orders(CustomerId, CreatedAt);

CREATE VIEW OpenOrders AS
SELECT Id, CustomerId, State, TotalCents, CreatedAt
FROM Orders
WHERE State NOT IN ('shipped', 'cancelled');

CREATE TRIGGER TR_Orders_StateAudit
AFTER UPDATE OF State ON Orders
WHEN OLD.State <> NEW.State
BEGIN
    INSERT INTO OrderAudit (OrderId, PreviousState, CurrentState)
    VALUES (NEW.Id, OLD.State, NEW.State);
END;
'@

Add-SqliteRow -DataSource $DatabasePath -On Customers -Data @{ Id = 1; Name = 'Example Customer' }
Add-SqliteRow -DataSource $DatabasePath -On Orders -Data @{ Id = 100; CustomerId = 1; TotalCents = 2599 }
Set-SqliteRow -DataSource $DatabasePath -On Orders -Values @{ State = 'paid' } -Where @{ Id = 100 } -Confirm:$false

Invoke-SqliteQuery -DataSource $DatabasePath -Query @'
SELECT o.Id, c.Name AS Customer, o.State, o.TotalCents
FROM OpenOrders o
JOIN Customers c ON c.Id = o.CustomerId;
'@ -As PSObject
