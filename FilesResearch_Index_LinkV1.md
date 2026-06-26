This is the navigation page for file/evidence investigation workflows.
It tells the assistant which protocol to load depending on the task type.

It should include:

— Link to Alert Investigation Protocol
For Sysmon, registry, service, TaskCache, Scheduled Task, process/path, ignore/monitor decisions.
https://raw.githubusercontent.com/Rasputin4149u/ChatGpt/refs/heads/main/FilesResearch_AlertInvestigation_Protocol.md
— Link to Claim Investigation Protocol
For documents, protocols, letters, replies, emails, videos, audio, transcripts, screenshots, and claim-evidence matrices.
https://raw.githubusercontent.com/Rasputin4149u/ChatGpt/refs/heads/main/ClaimInvestigation_Workflow_Protocol_LinkV1.md
— Routing Rule
If task is about security alert safety / ignore decision → load Alert protocol.
If task is about proving claims from evidence → load Claim protocol.
If both appear in one upload → load both, but keep findings separated.