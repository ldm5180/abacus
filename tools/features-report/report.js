// The living documentation: the fabula feature runner's Cucumber JSON
// (--report-json) turned into the HTML report published to GitHub
// Pages.  Usage: node report.js <json-dir> <html-dir>.  The commit and
// the run, when CI provides them, are shown on the page.

const report = require("multiple-cucumber-html-reporter");

const [jsonDir, reportPath] = process.argv.slice(2);

if (!jsonDir || !reportPath) {
  console.error("usage: node report.js <json-dir> <html-dir>");
  process.exit(2);
}

const commit = process.env.GITHUB_SHA || "local";
const run = process.env.GITHUB_RUN_ID
  ? `${process.env.GITHUB_SERVER_URL}/${process.env.GITHUB_REPOSITORY}/actions/runs/${process.env.GITHUB_RUN_ID}`
  : "local";

report.generate({
  jsonDir,
  reportPath,
  pageTitle: "abacus — features",
  reportName: "abacus — what the numerics do",
  pageFooter:
    "<div><p>The Gherkin features under tests/features/, run by fabula " +
    "against the real library.</p></div>",
  // fabula's report carries no step durations.
  displayDuration: false,
  hideMetadata: true,
  customData: {
    title: "Run",
    data: [
      { label: "Project", value: "abacus" },
      { label: "Commit", value: commit },
      { label: "Run", value: run },
    ],
  },
});
