import { existsSync, readFileSync } from "fs";
import {
  findExistingThread,
  createThread,
  updateThreadComment,
  setThreadStatus,
} from "./azure-devops";
import { getRequiredEnvVariable } from "./util";

const COMPARISON_FILE = "/tmp/comparison-sanitized.md";
const VIOLATION_PATTERN = /Found\s+[1-9]\d*\s+/;

function findComparisonMarkdown(): string | null {
  const candidates = [
    COMPARISON_FILE,
    "/tmp/scan-results/compare/merged-compare.md",
    "/tmp/scan-results/compare/sca-compare.md",
    "/tmp/scan-results/compare/iac-compare.md",
  ];

  for (const path of candidates) {
    if (existsSync(path)) {
      const content = readFileSync(path, "utf8").trim();
      if (content.length > 0) return content;
    }
  }
  return null;
}

async function postPrComment() {
  const markdown = findComparisonMarkdown();

  const orgUrl = getRequiredEnvVariable("SYSTEM_TEAMFOUNDATIONCOLLECTIONURI");
  const project = getRequiredEnvVariable("SYSTEM_TEAMPROJECT");
  const repoId = getRequiredEnvVariable("BUILD_REPOSITORY_ID");
  const prId = parseInt(
    getRequiredEnvVariable("SYSTEM_PULLREQUEST_PULLREQUESTID")
  );
  const token = getRequiredEnvVariable("SYSTEM_ACCESSTOKEN");

  const existingThread = await findExistingThread(
    orgUrl,
    project,
    repoId,
    prId,
    token
  );

  if (!markdown || !VIOLATION_PATTERN.test(markdown)) {
    console.info("No new findings to report.");
    if (existingThread) {
      const firstComment = existingThread.comments[0];
      if (firstComment) {
        await updateThreadComment(
          orgUrl, project, repoId, prId,
          existingThread.id, firstComment.id,
          "All issues previously detected by Lacework Code Security have been resolved!",
          token
        );
        await setThreadStatus(
          orgUrl, project, repoId, prId,
          existingThread.id, "closed",
          token
        );
        console.info("Existing thread resolved and closed.");
      }
    }
    return;
  }

  console.info(`Posting comparison results to PR #${prId}...`);

  if (existingThread) {
    const firstComment = existingThread.comments[0];
    if (firstComment) {
      console.info(
        `Found existing thread (ID=${existingThread.id}), updating...`
      );
      await updateThreadComment(
        orgUrl, project, repoId, prId,
        existingThread.id, firstComment.id,
        markdown,
        token
      );
      await setThreadStatus(
        orgUrl, project, repoId, prId,
        existingThread.id, "active",
        token
      );
      console.info("PR thread updated successfully.");
    }
  } else {
    console.info("No existing thread found, creating new one...");
    await createThread(orgUrl, project, repoId, prId, markdown, token);
    console.info("PR thread created successfully.");
  }
}

postPrComment().catch((e) => {
  console.error("Failed to post PR comment:", e.message || e);
  process.exit(1);
});
