const COMMENT_MARKER = "[](lacework-code-security)";
const PROPERTY_KEY = "lacework-code-security";
const API_VERSION = "api-version=7.1";

interface AzureDevOpsComment {
  id: number;
  content: string;
  commentType: string;
}

interface AzureDevOpsThread {
  id: number;
  status: string;
  comments: AzureDevOpsComment[];
  properties?: Record<string, { $type: string; $value: string }>;
}

interface ThreadsResponse {
  value: AzureDevOpsThread[];
  count: number;
}

function buildBaseUrl(
  orgUrl: string,
  project: string,
  repoId: string,
  prId: number
): string {
  const base = orgUrl.endsWith("/") ? orgUrl : `${orgUrl}/`;
  return `${base}${project}/_apis/git/repositories/${repoId}/pullRequests/${prId}`;
}

function authHeaders(token: string): Record<string, string> {
  const encoded = Buffer.from(`:${token}`).toString("base64");
  return {
    Authorization: `Basic ${encoded}`,
    "Content-Type": "application/json",
    Accept: "application/json",
  };
}

export async function findExistingThread(
  orgUrl: string,
  project: string,
  repoId: string,
  prId: number,
  token: string
): Promise<AzureDevOpsThread | null> {
  const url = `${buildBaseUrl(orgUrl, project, repoId, prId)}/threads?${API_VERSION}`;
  const response = await fetch(url, { headers: authHeaders(token) });
  if (!response.ok) {
    throw new Error(`Failed to list PR threads (status ${response.status})`);
  }
  const data: ThreadsResponse = (await response.json()) as ThreadsResponse;

  for (const thread of data.value) {
    if (
      thread.properties?.[PROPERTY_KEY]?.$value === "true"
    ) {
      return thread;
    }
    if (
      thread.comments?.some((c) => c.content?.includes(COMMENT_MARKER))
    ) {
      return thread;
    }
  }
  return null;
}

export async function createThread(
  orgUrl: string,
  project: string,
  repoId: string,
  prId: number,
  body: string,
  token: string
): Promise<void> {
  const url = `${buildBaseUrl(orgUrl, project, repoId, prId)}/threads?${API_VERSION}`;
  const payload = {
    comments: [
      {
        parentCommentId: 0,
        content: `${body}\n${COMMENT_MARKER}`,
        commentType: 1,
      },
    ],
    status: "active",
    properties: {
      [PROPERTY_KEY]: {
        $type: "System.String",
        $value: "true",
      },
    },
  };

  const response = await fetch(url, {
    method: "POST",
    headers: authHeaders(token),
    body: JSON.stringify(payload),
  });
  if (!response.ok) {
    const text = await response.text();
    throw new Error(
      `Failed to create PR thread (status ${response.status}): ${text}`
    );
  }
}

export async function updateThreadComment(
  orgUrl: string,
  project: string,
  repoId: string,
  prId: number,
  threadId: number,
  commentId: number,
  body: string,
  token: string
): Promise<void> {
  const url = `${buildBaseUrl(orgUrl, project, repoId, prId)}/threads/${threadId}/comments/${commentId}?${API_VERSION}`;
  const response = await fetch(url, {
    method: "PATCH",
    headers: authHeaders(token),
    body: JSON.stringify({ content: `${body}\n${COMMENT_MARKER}` }),
  });
  if (!response.ok) {
    const text = await response.text();
    throw new Error(
      `Failed to update PR comment (status ${response.status}): ${text}`
    );
  }
}

export async function setThreadStatus(
  orgUrl: string,
  project: string,
  repoId: string,
  prId: number,
  threadId: number,
  status: string,
  token: string
): Promise<void> {
  const url = `${buildBaseUrl(orgUrl, project, repoId, prId)}/threads/${threadId}?${API_VERSION}`;
  const response = await fetch(url, {
    method: "PATCH",
    headers: authHeaders(token),
    body: JSON.stringify({ status }),
  });
  if (!response.ok) {
    const text = await response.text();
    throw new Error(
      `Failed to update thread status (status ${response.status}): ${text}`
    );
  }
}
