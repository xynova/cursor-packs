---
name: review-member-visibility
description: Audits Go packages for visibility (export only what's essential). Use when the user asks to review visibility, audit exports, or reduce public API surface.
---

# Review Member Visibility

**Principle:** Export only what's essential (public API interfaces, constructors, shared domain/DTOs). Keep implementation structs and internal helpers private.

---

## 1. Scope

Default: path the user gave. If unspecified, suggest `internal/` (or the project's main package tree).

---

## 2. List exported symbols

Per package in scope:

```bash
grep -rn "^type [A-Z]" <pkg_path> --include="*.go"
grep -rn "^func [A-Z]\|^var [A-Z]\|^const [A-Z]" <pkg_path> --include="*.go"
```

Record: package, symbol, file:line, kind.

---

## 3. Decision tree (per symbol)

1. **Used outside this package?** (Search for `pkg.Symbol` outside the package.) **NO** → private. **YES** → continue.
2. **Public API?** (Interface callers use, constructor, shared DTO, client interface for DI.) **NO** → private. **YES** → continue.
3. **Constructor (New*)?** → keep public.
4. **Interface for DI/testing or shared DTO?** → keep public.
5. **Otherwise** → private.

**Keep public:** Interfaces as param/return, DTOs used elsewhere, constructors.  
**Make private:** Impl structs (callers use interface + New*), internal helpers, internal interfaces, config/prompt vars only for building exports.

---

## 4. Report

Summary (Compliant / Partial / Violations). Per package: justified public; violations with file:line and reason. Per violation: concrete fix (e.g. rename to unexported, update refs in package).

---

## 5. Fix (if user asked to fix)

Rename violations to unexported; update refs in same package. Constructors return interface. `make build`; fix broken refs elsewhere. Re-run this skill on changed packages.
