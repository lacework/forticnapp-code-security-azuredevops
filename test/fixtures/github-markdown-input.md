### Lacework Code Security

When a Pull Request in a repository is submitted, the Lacework FortiCNAPP runs scans on both the source and target branches and compares the results to identify any issues / vulnerabilities which will be introduced by the source branch.
[See summary in Lacework FortiCNAPP](https://uedemo.lacework.net/ui/codesec)

#### <ins>3rd Party Vulnerabilities</ins> - Found 1 package(s) which introduces 3 new CVE(s) - Severity: ❌&nbsp;Critical

<details><summary>Expand Details</summary>

The Lacework FortiCNAPP's SCA tool identified the following vulnerabilities.
<table>
    <thead>
        <tr>
            <th rowspan="2">Package</th>
            <th rowspan="2">Location</th>
            <th colspan="2">Vulnerabilities (CVEs)</th>
            <th rowspan="2">Fix Version</th>
        </tr>
        <tr>
            <th>Direct</th>
            <th>Transitive</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td>golang.org/x/crypto@0.14.0</td>
            <td><a target="_blank" href="https://github.com/example/repo/blob/abc123/go.mod#L5">go.mod#L5</a><br><sup>./</sup><br></td>
            <td>❌&nbsp;Critical:&nbsp;1<br>🟧&nbsp;Medium:&nbsp;2</td>
            <td>-</td>
            <td>0.31.0</td>
        </tr>
        <tr>
            <td colspan="5"><details><summary>Expand Details</summary>
                <table>
                    <thead>
                        <tr>
                            <th>Vulnerability ID</th>
                            <th>Severity</th>
                            <th>Dependency<br><sup>Direct / Transitive</sup></th>
                            <th>Fix Version</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr>
                            <td><a target="_blank" href="https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2024-45337">CVE-2024-45337</a></td>
                            <td>❌&nbsp;Critical</td>
                            <td>golang.org/x/crypto@0.14.0<br><sup>Direct</sup></td>
                            <td>0.31.0</td>
                        </tr>
                        <tr>
                            <td><a target="_blank" href="https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2023-48795">CVE-2023-48795</a></td>
                            <td>🟧&nbsp;Medium</td>
                            <td>golang.org/x/crypto@0.14.0<br><sup>Direct</sup></td>
                            <td>0.17.0</td>
                        </tr>
                        <tr>
                            <td><a target="_blank" href="https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2025-22869">CVE-2025-22869</a></td>
                            <td>🟧&nbsp;Medium</td>
                            <td>golang.org/x/crypto@0.14.0<br><sup>Direct</sup></td>
                            <td>0.35.0</td>
                        </tr>
                    </tbody>
                </table></details>
            </td>
        </tr>
    </tbody>
</table>

---
</details>

####  <ins>Internal Code</ins> - Found 2 new potential issue(s) - Severity: 🟧&nbsp;Medium

<details><summary>Expand Details</summary>

The Lacework FortiCNAPP SAST scanner detected the following issues.

| Issue | Description | Location | Severity |
|-------|-------------|----------|----------|
| **XXE Vulnerability** <br><sup>CWE-611</sup> | XML parser with external entities enabled | <a target="_blank" href="https://github.com/example/repo/blob/abc123/App.java#L10">App.java#L10</a><br><sup>./</sup><br> | 🟧&nbsp;Medium |
| **Insecure Cipher** <br><sup>CWE-327</sup> | Use of broken cryptographic algorithm | <a target="_blank" href="https://github.com/example/repo/blob/abc123/App.java#L24">App.java#L24</a><br><sup>./</sup><br> | 🟧&nbsp;Medium |

---
</details>

#### <ins>Hard-coded Secrets</ins> - Found 1 new potential exposed secret(s) - Severity: 🛑&nbsp;High

<details><summary>Expand Details</summary>

The Lacework FortiCNAPP's SCA tool found the following secrets.

| Secret | Category | Location | Severity |
|--------|----------|----------|----------|
| **Generic Password Credentials** | Generic | <a target="_blank" href="https://github.com/example/repo/blob/abc123/config.ts#L1">config.ts#L1</a><br><sup>./</sup><br> | 🛑&nbsp;High

---
</details>

#### <ins>Violations</ins> - Found 2 new potential violations - Severity: ❌&nbsp;Critical

<details><summary>Expand Details</summary>

The Lacework FortiCNAPP's IaC tool found the following violations.

| Violation | Description | Location | Severity |
|-----------|-------------|----------|----------|
| **S3 bucket does not block public access** | S3 buckets should have all `block public access` options enabled. | <a target="_blank" href="https://github.com/example/repo/blob/abc123/main.tf#L1">main.tf#L1</a><br><sup>./</sup><br> | ❌&nbsp;Critical
| **RDS instance is publicly accessible** | Ensure that RDS database instances restrict unauthorized access. | <a target="_blank" href="https://github.com/example/repo/blob/abc123/main.tf#L50">main.tf#L50</a><br><sup>./</sup><br> | 🛑&nbsp;High

---
</details>

For more information, please refer to the [exceptions guide](https://docs.fortinet.com/document/forticnapp/latest/administration-guide/975371#Exceptions)

<!--- lacework-code-analysis: abc123 --->
