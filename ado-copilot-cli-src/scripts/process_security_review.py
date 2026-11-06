import argparse
import html
import json
import sys
from pathlib import Path, PurePosixPath


SEVERITY_RANK = {"low": 1, "medium": 2, "high": 3, "critical": 4}
GHAS_COVERAGE = {
    "codeql",
    "dependency-scanning",
    "secret-scanning",
    "not-covered",
    "unknown",
}
REQUIRED_FINDING_FIELDS = {
    "rank",
    "severity",
    "confidence",
    "title",
    "category",
    "cwe",
    "file",
    "lineStart",
    "lineEnd",
    "evidence",
    "impact",
    "recommendation",
    "validation",
    "ghasCoverage",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--repository-root", required=True, type=Path)
    parser.add_argument(
        "--fail-on",
        choices=tuple(SEVERITY_RANK),
        default="high",
    )
    parser.add_argument("--mode", choices=("advisory", "enforce"), default="advisory")
    return parser.parse_args()


def require_text(value: object, field: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{field} must be a non-empty string")
    return value.strip()


def validate_finding(
    finding: object,
    expected_rank: int,
    repository_root: Path,
) -> dict:
    if not isinstance(finding, dict):
        raise ValueError(f"finding {expected_rank} must be an object")

    missing = REQUIRED_FINDING_FIELDS - finding.keys()
    if missing:
        raise ValueError(
            f"finding {expected_rank} is missing: {', '.join(sorted(missing))}"
        )

    if finding["rank"] != expected_rank:
        raise ValueError(f"finding ranks must be consecutive from 1")

    severity = require_text(finding["severity"], "severity").lower()
    if severity not in SEVERITY_RANK:
        raise ValueError(f"finding {expected_rank} has invalid severity")

    confidence = finding["confidence"]
    if type(confidence) is not int or not 1 <= confidence <= 10:
        raise ValueError(
            f"finding {expected_rank} confidence must be a JSON integer from "
            f"1 through 10; received {confidence!r}. Probabilities, percentages, "
            "strings, and booleans are not supported. Correct the review output "
            "using the prompt's 1-10 confidence scale."
        )

    file_name = require_text(finding["file"], "file").replace("\\", "/")
    relative_path = PurePosixPath(file_name)
    if relative_path.is_absolute() or ".." in relative_path.parts:
        raise ValueError(f"finding {expected_rank} has an unsafe file path")

    source_path = repository_root.joinpath(*relative_path.parts).resolve()
    repository_root = repository_root.resolve()
    if repository_root not in source_path.parents or not source_path.is_file():
        raise ValueError(f"finding {expected_rank} references a missing file")

    line_start = finding["lineStart"]
    line_end = finding["lineEnd"]
    line_count = len(source_path.read_text(encoding="utf-8").splitlines())
    if (
        not isinstance(line_start, int)
        or not isinstance(line_end, int)
        or line_start < 1
        or line_end < line_start
        or line_end > line_count
    ):
        raise ValueError(f"finding {expected_rank} has invalid line numbers")

    coverage = require_text(finding["ghasCoverage"], "ghasCoverage").lower()
    if coverage not in GHAS_COVERAGE:
        raise ValueError(f"finding {expected_rank} has invalid GHAS coverage")

    cwe = finding["cwe"]
    if cwe is not None and (
        not isinstance(cwe, str) or not cwe.startswith("CWE-")
    ):
        raise ValueError(f"finding {expected_rank} has invalid CWE")

    validated = dict(finding)
    validated["severity"] = severity
    validated["file"] = file_name
    validated["ghasCoverage"] = coverage
    for field in (
        "title",
        "category",
        "evidence",
        "impact",
        "recommendation",
        "validation",
    ):
        validated[field] = require_text(finding[field], field)
    return validated


def load_and_validate(input_path: Path, repository_root: Path) -> dict:
    try:
        review = json.loads(input_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise ValueError(f"Copilot output is not valid JSON: {error}") from error

    if not isinstance(review, dict) or review.get("schemaVersion") != "1.0":
        raise ValueError("review must use schemaVersion 1.0")

    review["executiveSummary"] = require_text(
        review.get("executiveSummary"),
        "executiveSummary",
    )

    findings = review.get("findings")
    if not isinstance(findings, list) or len(findings) > 10:
        raise ValueError("findings must be an array containing at most 10 items")

    review["findings"] = [
        validate_finding(finding, index, repository_root)
        for index, finding in enumerate(findings, start=1)
    ]

    expected_order = sorted(
        review["findings"],
        key=lambda item: (-SEVERITY_RANK[item["severity"]], -item["confidence"]),
    )
    if review["findings"] != expected_order:
        raise ValueError("findings must be ordered by severity and confidence")

    limitations = review.get("limitations")
    if not isinstance(limitations, list):
        raise ValueError("limitations must be an array")
    review["limitations"] = [
        require_text(item, "limitation") for item in limitations
    ]
    return review


def markdown_text(value: object) -> str:
    return html.escape(str(value), quote=False).replace("\r", " ").replace("\n", " ")


def markdown_cell(value: object) -> str:
    return markdown_text(value).replace("|", r"\|")


def render_markdown(review: dict) -> str:
    lines = [
        "# Copilot security review",
        "",
        "> Advisory AI analysis. Validate each finding before remediation. "
        "This does not replace GHAS, threat modeling, or human review.",
        "",
        "## Executive summary",
        "",
        markdown_text(review["executiveSummary"]),
        "",
        "## Ranked findings",
        "",
    ]

    findings = review["findings"]
    if not findings:
        lines.append("No evidence-backed findings were reported.")
    else:
        lines.extend(
            [
                "| Rank | Severity | Confidence | Finding | Location | GHAS overlap |",
                "|---:|---|---:|---|---|---|",
            ]
        )
        for finding in findings:
            location = (
                f"{finding['file']}:{finding['lineStart']}"
                f"-{finding['lineEnd']}"
            )
            lines.append(
                f"| {finding['rank']} | {finding['severity'].upper()} "
                f"| {finding['confidence']}/10 | {markdown_cell(finding['title'])} "
                f"| `{markdown_cell(location)}` "
                f"| {finding['ghasCoverage']} |"
            )

        for finding in findings:
            lines.extend(
                [
                    "",
                    f"### {finding['rank']}. {markdown_text(finding['title'])}",
                    "",
                    f"- **Severity:** {finding['severity'].upper()}",
                    f"- **Confidence:** {finding['confidence']}/10",
                    f"- **Category:** {markdown_text(finding['category'])}",
                    f"- **CWE:** {markdown_text(finding['cwe'] or 'Not assigned')}",
                    f"- **Location:** `{markdown_text(finding['file'])}:{finding['lineStart']}"
                    f"-{finding['lineEnd']}`",
                    f"- **Likely GHAS overlap:** {finding['ghasCoverage']}",
                    f"- **Evidence:** {markdown_text(finding['evidence'])}",
                    f"- **Impact:** {markdown_text(finding['impact'])}",
                    f"- **Recommendation:** {markdown_text(finding['recommendation'])}",
                    f"- **Validation:** {markdown_text(finding['validation'])}",
                ]
            )

    lines.extend(["", "## Limitations", ""])
    if review["limitations"]:
        lines.extend(f"- {markdown_text(item)}" for item in review["limitations"])
    else:
        lines.append("- No additional limitations were supplied.")

    lines.extend(
        [
            "",
            "## Recommended operating model",
            "",
            "Use Copilot to prioritize contextual risks and suggest validation "
            "steps. Use GHAS for deterministic CodeQL, dependency, and secret "
            "scanning where available. Keep human approval for remediation.",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    try:
        review = load_and_validate(args.input, args.repository_root)
    except (ValueError, OSError) as error:
        print(
            f"Security review validation failed: {error}\n"
            "This is a report-processing failure, not a security finding gate. "
            "Inspect the raw security-review.json artifact.",
            file=sys.stderr,
        )
        return 1

    threshold = SEVERITY_RANK[args.fail_on]
    gate_triggered = any(
        SEVERITY_RANK[finding["severity"]] >= threshold
        for finding in review["findings"]
    )
    status = (
        f"At least one {args.fail_on}-or-higher finding was reported."
        if gate_triggered
        else f"No {args.fail_on}-or-higher findings were reported."
    )
    if args.mode == "advisory":
        status += " Advisory mode: security findings do not fail the pipeline."
    elif gate_triggered:
        status += " Enforce mode: the separate security gate will fail the pipeline."
    else:
        status += " Enforce mode: the security gate will not fail the pipeline."
    args.output.write_text(
        render_markdown(review) + f"\n## Pipeline policy\n\n{status}\n",
        encoding="utf-8",
    )
    print(status)
    print(
        "##vso[task.setvariable variable=copilotGateTriggered]"
        f"{str(gate_triggered).lower()}"
    )
    print(f"##vso[task.uploadsummary]{args.output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
