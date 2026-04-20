# Epic 13: Documentation Sync

Bring documentation in line with the actual implementation state.

## Story 13.1: Consolidate Architecture Documents

As a developer,
I want a single authoritative architecture document,
So that there is no confusion about which doc is current.

**Acceptance Criteria:**

**Given** multiple architecture-related documents may exist
**When** consolidation is complete
**Then** one document is the canonical source and any others are deleted or replaced with a redirect
**And** the surviving document reflects the current tech stack, navigation, and feature set

## Story 13.2: Update PRD to Match Implementation

As a product owner,
I want the PRD to accurately describe what is built,
So that it serves as reliable reference for future planning.

**Acceptance Criteria:**

**Given** the PRD contradicts the implementation in multiple areas
**When** the update is complete
**Then** achievement count and descriptions are accurate
**And** global upgrades and continent upgrades are documented
**And** daily rewards system is documented
**And** the Leaders tab and bottom navigation are documented
**And** Section 10 no longer says "No continent-wide or global upgrades are implemented yet"

## Story 13.3: Add Project README

As a new developer,
I want a README.md at the project root,
So that I immediately understand what the project is, how to set it up, and how to run it.

**Acceptance Criteria:**

**Given** no `README.md` exists at the project root
**When** the README is created
**Then** it includes: project description, prerequisites, setup instructions, run commands, project structure overview, and link to `docs/` for detailed documentation

---
