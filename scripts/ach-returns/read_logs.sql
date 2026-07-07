SELECT TOP 1000 *
	FROM dbo.Traces
	WHERE Timestamp > '2025-10-16'
	and MessageTemplate like '%AchReturnedEventHandler%' -- AchReturnedEventHandler  AchReturnReceivedEvent
	ORDER BY TimeStamp DESC