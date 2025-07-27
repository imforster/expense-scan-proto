# Create PR After Major Task Completion

## Hook Configuration

**Trigger**: Manual button click
**Name**: Create PR for Task
**Description**: Creates a pull request after completing a major task with all changes and a descriptive commit message

## Hook Logic

When this hook is triggered:

1. Check git status to see what files have been modified
2. Stage all changes related to the completed task
3. Create a descriptive commit message based on the task that was completed
4. Commit the changes
5. Create a new branch if not already on a feature branch
6. Push the branch to remote
7. Create a pull request with:
   - Title describing the completed task
   - Description including task details and changes made
   - Reference to the spec and task number

## Implementation

```javascript
// Hook implementation would go here
// This is a template for the agent hook system
async function createPRAfterTask() {
  // Get current git status
  const gitStatus = await git.status();
  
  // Stage all changes
  await git.add('.');
  
  // Create commit message based on completed task
  const commitMessage = generateCommitMessage();
  
  // Commit changes
  await git.commit(commitMessage);
  
  // Create/switch to feature branch if needed
  const branchName = generateBranchName();
  await git.createBranch(branchName);
  
  // Push to remote
  await git.push();
  
  // Create PR
  await createPullRequest({
    title: generatePRTitle(),
    description: generatePRDescription(),
    branch: branchName
  });
}
```

## Usage

Click the "Create PR for Task" button after completing any major task to automatically:
- Commit all changes with a descriptive message
- Create a feature branch if needed
- Push changes to remote
- Open a pull request for review

This ensures consistent PR creation and helps maintain a clean git history with proper task tracking.