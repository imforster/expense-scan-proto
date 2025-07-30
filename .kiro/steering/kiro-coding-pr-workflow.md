# Kiro Coding and PR Workflow Guide

## Overview

This guide defines best practices for using Kiro's AI-assisted development workflow, from feature conception through pull request creation. It leverages Kiro's spec-driven development, task management, and integrated AI capabilities.

## Kiro-Specific Workflow

### Phase 1: Feature Planning with Specs

#### 1.1 Create Feature Spec
Use Kiro's spec workflow to transform ideas into structured implementation plans:

```
"Create a spec for [feature description]"
```

This generates:
- `requirements.md` - EARS format requirements with user stories
- `design.md` - Architecture and technical design
- `tasks.md` - Actionable implementation checklist

#### 1.2 Spec Review Process
- Review each document (requirements → design → tasks)
- Iterate with Kiro until each phase is approved
- Ensure tasks reference specific requirements

### Phase 2: Branch and Task Execution

#### 2.1 Branch Creation
Create feature branches aligned with spec names:

```bash
git checkout -b feat/[spec-name]
# Example: git checkout -b feat/light-dark-theme
```

#### 2.2 Task-Driven Development
Execute tasks from the spec's `tasks.md`:

1. Open the spec's `tasks.md` file
2. Click "Start task" next to specific task items
3. Let Kiro execute ONE task at a time
4. Review implementation before proceeding
5. Ensure we create a feature branch for the associated task

**Key Principles:**
- Execute tasks sequentially, not in parallel
- Complete sub-tasks before parent tasks
- Stop after each task for review
- Use task status tracking (`taskStatus` tool)
- **ALL TESTS MUST PASS before marking any task as complete**
- Fix any compilation errors or test failures before proceeding

#### 2.3 Context-Aware Implementation
Kiro automatically includes relevant context:
- Spec requirements and design documents
- Related files via `#File` or `#Folder`
- Codebase knowledge via `#Codebase`
- Current problems via `#Problems`

### Phase 3: Quality Assurance

#### 3.1 Built-in Testing
Kiro includes comprehensive testing in task implementation:
- Unit tests for new functionality
- Integration tests where appropriate
- Test coverage verification

#### 3.2 Build Verification
Verify builds succeed after each task:
```bash
# iOS/Swift projects
xcodebuild -project [ProjectName].xcodeproj -scheme [SchemeName] build

# Other platforms as appropriate
```

#### 3.3 Functionality Validation
Test the implemented feature manually to ensure it meets requirements.

### Phase 4: Commit and PR Creation

#### 4.1 Atomic Commits
Create meaningful commits after completing related tasks:

```bash
git add [relevant-files]
git commit -m "feat([scope]): [description]

- [specific change 1]
- [specific change 2]
- [reference to requirements]"
```

#### 4.2 Comprehensive PR Creation
When feature is complete, Kiro can assist with PR creation:

1. Stage all changes: `git add .`
2. Create descriptive commit message
3. Push branch: `git push origin feat/[spec-name]`
4. Create PR with:
   - Feature summary
   - Requirements addressed
   - Implementation approach
   - Testing performed

## Kiro-Specific Best Practices

### Leverage Kiro's Context System
- Use `#File` to include specific files in context
- Use `#Folder` for directory-level context
- Use `#Codebase` for project-wide understanding
- Reference `#Problems` for current issues

### Spec-Driven Development
- Always start with a spec for complex features
- Use spec tasks as the single source of truth
- Reference requirements in commits and PRs
- Update task status as work progresses

### Incremental Development
- Execute one task at a time
- Review each implementation before proceeding
- Build and test after significant changes
- Commit frequently with meaningful messages

### AI Collaboration
- Provide clear, specific requests to Kiro
- Review and understand generated code
- Ask for explanations of complex implementations
- Iterate on solutions when needed
- **Never mark tasks complete with failing tests** - Always fix compilation and test issues first

## Quality Gates

Before marking any task as complete, ensure:

- [ ] **ALL TESTS PASS** - No compilation errors or test failures
- [ ] Code builds successfully without warnings
- [ ] Implementation meets all task requirements
- [ ] Code follows project conventions

Before creating a PR, ensure:

- [ ] All spec tasks are completed and marked as done
- [ ] Code builds successfully
- [ ] Tests pass (unit and integration)
- [ ] Feature functionality verified manually
- [ ] Code follows project conventions
- [ ] Commit messages are descriptive
- [ ] No unrelated changes included

## Reverting and Recovery

### Task-Level Reversion
If a task implementation has issues:
1. Use git to revert specific commits
2. Mark task as "not_started" in spec
3. Re-execute the task with refined approach

### Feature-Level Reversion
For major issues with entire feature:
```bash
git reset --hard origin/main
# Or create revert commits for pushed changes
git revert [commit-range]
```

### Spec Updates
If requirements change during development:
1. Update the spec documents
2. Adjust remaining tasks accordingly
3. Document changes in PR description

## Integration with Kiro Features

### Hooks
Set up agent hooks for automated workflows:
- Auto-run tests on file save
- Update documentation on code changes
- Validate code style on commit

### Steering Rules
Use steering files to maintain consistency:
- Project-specific coding standards
- Architecture guidelines
- Testing requirements

### MCP Tools
Leverage MCP integrations for:
- External API documentation
- Cloud service integration
- Specialized tooling

## Success Metrics

| Metric | Target |
|--------|--------|
| **Spec Completion** | All tasks marked complete |
| **Build Success** | Clean builds throughout development |
| **Test Coverage** | Comprehensive test suite included and all tests are passing |
| **Requirements Traceability** | All requirements addressed |
| **Code Quality** | Follows project standards |
| **Documentation** | Clear PR description with context |

## Example Workflow

1. **Planning**: "Create a spec for user authentication"
2. **Spec Creation**: Review requirements → design → tasks
3. **Branch**: `git checkout -b feat/user-authentication`
4. **Implementation**: Execute tasks one by one with Kiro
5. **Testing**: Verify functionality and run test suite
6. **Commit**: Create atomic commits with clear messages
7. **PR**: Push branch and create comprehensive pull request

This workflow ensures high-quality, traceable, and maintainable code development with Kiro's AI assistance.
