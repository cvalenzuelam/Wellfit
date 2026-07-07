Some direction for QA - Initial QA testing on QA Environment

Database - qa-platform-wellfit-sqlserver.database.windows.net
Set up - create_test_payment_records.sql - on Platform
Set up - read_logs.sql - on Platform
Set up - create_test_return_configuration.sql - on Payments

Powershell and Test Data - Create Initial Events
Set up - publish-qa-ach-returns-from-csv.ps1 - on Local Machine
Set up - test_returns_2025-09-18.csv - on Local Machine
Run in Powershell

Look at Logs - qa-insights on Azure Portal and logs/traces on Platform SQL (setup above)
ReturnNotificationReceivedEvent - Step 1 - DataServices Generates this Event - Consumed by AchReturns
AchReturnReceivedEvent - Step 2 - AchReturns Generates this Event - Consumed by Payments
RedepositAttemptedEvent - Step 3 - Payments Generates this Event - Consumed by AchReturns and Other Services - Cannot Yet Generate - No way to successfully process a retry on WP

qa-insights - search for ReturnNotificationReceivedEvent
sql - search for AchReturnedEventHandler

Normally - Happy Path - See in AchReturns and Payments - Step 1 and 2

Change 83997656989609888 to 83997656989609889 - No Payment Found - Does not go past Step 1
Change 100.0 to 100.01 - Amount Mismatch - Does not go past Step 1

Change R01 to R02 - RedepositEligible False - Goes to Step 2 - RedepositEligible false
Change create_test_payment_records.sql SYSDATETIMEOFFSET() to 2025-07-01 - Return notification beyond - Goes to Step 2 - RedepositEligible false
Change create_test_return_configuration.sql delete configurations - No ReturnConfiguration - Goes to Step 2 - RedepositEligible false
Change Max Atempts - There can be MANY permutations of this - Misc MaxRedepositAttempts - Goes to Step 2 - RedepositEligible false






