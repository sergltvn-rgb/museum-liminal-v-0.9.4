import { Worker } from "@notionhq/workers";

const worker = new Worker();
export default worker;

// Webhook to receive feedback from the Godot game
worker.webhook("submitFeedback", {
	title: "Submit Game Feedback",
	description: "Creates a new feedback entry from the game in a Notion database",
	execute: async (events, { notion }) => {
		for (const event of events) {
			const { playerName, comment, version } = event.body as {
				playerName?: string;
				comment?: string;
				version?: string;
			};

			if (!comment) {
				console.log("Empty comment received, skipping.");
				continue;
			}

			const name = playerName || "Anonymous Player";
			const gameVersion = version || "unknown";

			// 1. Try to get Database ID from environment variables
			let databaseId = process.env.FEEDBACK_DATABASE_ID;

			// 2. If not set, search for a database named "Museum Feedback"
			if (!databaseId) {
				console.log("FEEDBACK_DATABASE_ID env var not set. Searching for database 'Museum Feedback'...");
				const searchResponse = await notion.search({
					query: "Museum Feedback",
					filter: {
						property: "object",
						value: "database",
					},
				});

				if (searchResponse.results.length > 0) {
					databaseId = searchResponse.results[0].id;
					console.log(`Found database 'Museum Feedback' with ID: ${databaseId}`);
				} else {
					console.error("Database 'Museum Feedback' not found. Please create it or set FEEDBACK_DATABASE_ID.");
					throw new Error("Feedback database not found");
				}
			}

			// 3. Create a page in the database
			await notion.pages.create({
				parent: { database_id: databaseId },
				properties: {
					// In Notion, the default title column is typically named "Name"
					Name: {
						title: [
							{
								text: {
									content: `${name} (v${gameVersion})`,
								},
							},
						],
					},
					// Custom text column "Feedback"
					Feedback: {
						rich_text: [
							{
								text: {
									content: comment,
								},
							},
						],
					},
				},
			});

			console.log(`Successfully saved feedback from ${name}`);
		}
	},
});
