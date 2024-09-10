# Check that the PR contains changes to the CHANGELOG.md file.
unless git.modified_files.include?('CHANGELOG.md')
  warn('Please add an entry in the `CHANGELOG.md` file to describe the changes made by this PR')
end

pr_size_checker.check_diff_size(max_size: 500)

# skip remaining checks if the PR is still a Draft
if github.pr_draft?
  message('This PR is still a Draft: some checks will be skipped.')
  return
end

labels_checker.check(
  do_not_merge_labels: ['do not merge'],
  required_labels: []
)

warn("This PR has no reviewers. Please request a review from **@\u2060Automattic/apps-infrastructure**.") unless github_utils.requested_reviewers?
