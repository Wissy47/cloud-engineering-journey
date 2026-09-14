# Day 6 — Git, GitHub & Cloud Engineering Documentation

## Objective

Learn how to use Git to track cloud-engineering work, create meaningful commit history, organize lab documentation, and prepare a repository for GitHub and portfolio use.

## Topics Covered

* Git fundamentals
* Git repositories
* Working directory
* Staging area
* Commits
* Commit history
* `git status`
* `git add`
* `git commit`
* `git log`
* `git diff`
* Markdown documentation
* Repository organization
* Cloud lab journaling
* Portfolio documentation

## Git Setup

I verified Git with:

```bash
git --version
```

I also checked my global Git identity:

```bash
git config --global user.name
git config --global user.email
```

Git uses this information to identify the author of commits.

## Creating the Repository

I created a repository for my cloud-engineering journey:

```bash
mkdir -p ~/cloud-engineering-journey
cd ~/cloud-engineering-journey
git init
```

Git initialized the repository on the `main` branch.

## Repository Structure

The repository was organized as:

```text
cloud-engineering-journey/
├── README.md
└── week-1/
    ├── day-1.md
    ├── day-2.md
    ├── day-3.md
    ├── day-4.md
    ├── day-5.md
    ├── day-6.md
    └── day-7.md
```

This structure makes the learning journey easy to navigate.

## Git Status

I used:

```bash
git status
```

to understand the current state of the repository.

Before staging, files appeared as:

```text
Untracked files
```

After staging, they appeared under:

```text
Changes to be committed
```

After committing, Git reported:

```text
nothing to commit, working tree clean
```

## Git Workflow

The core Git workflow I practiced was:

```text
Edit files
   ↓
git status
   ↓
git diff
   ↓
git add
   ↓
staging area
   ↓
git commit
   ↓
Git history
```

## Staging Files

I staged files using:

```bash
git add .
```

and also practiced staging specific files:

```bash
git add week-1/day-1.md
```

Staging lets me decide exactly what belongs in the next commit.

## Commits

I created meaningful commits such as:

```text
Initialize cloud engineering journey
Document Week 1 Day 1 Linux fundamentals
Document Week 1 Day 2 Linux networking
Document Week 1 Day 3 AWS and IAM fundamentals
Document Week 1 Day 4 EC2 and security groups
Document Week 1 Day 5 Linux administration
```

I learned that a good commit should represent one clear logical change.

## Commit History

I inspected repository history with:

```bash
git log --oneline
```

This showed shortened commit IDs and messages.

Example:

```text
c5f021d Document Week 1 Day 5 Linux administration
bb608d2 Document Week 1 Day 4 EC2 and security groups
```

## HEAD and Branches

The log displayed:

```text
HEAD -> main
```

This means:

```text
HEAD → current checked-out commit
main → current branch
```

## Git Diff

I used:

```bash
git diff
```

to inspect changes before staging.

I also used:

```bash
git diff -- week-1/day-2.md
```

to inspect one specific file.

This is useful for reviewing work before committing it.

## Markdown Documentation

I documented each lab using Markdown.

Useful Markdown syntax included:

```text
# Heading
## Subheading
- list item
```

and fenced code blocks for commands and terminal output.

## Documentation Structure

Each lab entry follows a consistent structure:

```text
Objective
Topics Covered
Commands Practiced
Key Concepts
Troubleshooting
What I Learned
Lab Outcome
```

This makes the documentation useful for:

* revision
* interviews
* portfolio evidence
* LinkedIn content
* future troubleshooting reference

## Root README

The repository README explains:

* the purpose of the project
* the 12-week cloud transition
* current progress
* tools used
* repository structure

A good README allows someone unfamiliar with the repository to quickly understand what it contains.

## Why Documentation Matters in Cloud Engineering

Cloud engineers frequently need to document:

* architectures
* troubleshooting steps
* incidents
* commands
* deployments
* configuration changes
* infrastructure decisions
* runbooks

Documentation is therefore part of engineering work, not an optional extra.

## Security Considerations

Before publishing cloud repositories, sensitive information must be excluded.

Examples that should never be committed include:

```text
AWS access keys
private SSH keys
passwords
API tokens
.env files containing secrets
production credentials
```

The private SSH key:

```text
~/.ssh/id_ed25519
```

must never be added to a public repository.

## Git Mental Model

A useful mental model is:

```text
Working directory
      ↓
    git add
      ↓
Staging area
      ↓
  git commit
      ↓
Repository history
      ↓
   GitHub
```

## What I Learned

I learned that Git is more than a backup tool.

It provides a history of engineering decisions and makes it possible to understand:

* what changed
* when it changed
* who changed it
* why it changed

I also learned how good documentation can turn hands-on cloud labs into evidence of practical experience.

## Lab Outcome

By the end of Day 6, I was able to:

* initialize a Git repository
* inspect repository status
* stage files
* create focused commits
* inspect commit history
* review changes with `git diff`
* organize cloud labs using Markdown
* maintain a meaningful engineering journal
* prepare a repository for GitHub and portfolio use

