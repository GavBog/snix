---
title: "Announcing Snix"
description: "Announcing the Snix Project"
date: 2025-03-16T15:32:28+00:00
lastmod: 2025-03-16T15:32:28+00:00
draft: false
weight: 50
categories: []
tags: []
contributors: []
pinned: false
homepage: false
---

## A New Chapter

For a long time now, Tvix development has been a bit of a tug-of-war between
differing priorities. The TVL community's side project, or Tvix as an end in its
own right. The evaluator front and center, or castore as the major innovation.
The repository itself, the contributor onboarding flow, and even the choice of
IRC channel have laboured under these conflicting views of Tvix's future.

Snix is where we're hoping to put this to a rest, on infrastructure and
community dedicated to driving an innovative implementation of Nix forward.

## Background

While initially being homed in the TVL community, for a while now already,
most Tvix development has been going on in a separate `#tvix-dev` IRC
channel, with little overlap with TVL.

Onboarding new contributors was hard in general:
 - Newcomers had to clone the entire monorepo to contribute, bringing in a lot
   of unrelated projects, that are confusing at best.
 - Having all these projects made navigation hard, and changing some things in
   one place caused regressions far away in another corner of the repository.
 - Onboarding frequently required sending patches via email, as the SSO login
   process was somewhat neglected.

There's been different requirements on CI for Tvix and TVL:
 - TVL overrides Nix to their 2.3 fork in their nixpkgs instance, which
   frequently causes rebuilds for contributors, caused CI deadlocks in the
   past, and most recently an entirely broken build for all contributors on
   MacOS.
 - Tvix has an extensive regression test suite, and nixpkgs bumps regularly
   caused them to fail, requiring investigation. However, as some peoples'
   system configurations are also in the monorepo, and they have an interest
   in getting nixpkgs updates quickly, causing Tvix tests to frequently get
   disabled, risking breakage of Tvix functionality.

There have also been a few disagreements on which areas of Tvix development
should be prioritized, and how certain things should be architected.

# Snix

Rather than continuing to navigate all these conflicting priorities, and
spending lots of time coming up with a compromise both sides are not really
happy about, I think it's better to put the project on its own legs, not only
in terms of community, but also in terms of where it's hosted, using a new name,
**Snix**.

The fork will:

 - allow tailoring the surrounding build infrastructure to the needs of Snix
 - make contributions easier, allowing for a broader contributor base
 - unblock some long-deadlocked decisions on the future of Tvix development

We're excited to work with new and existing contributors to Tvix and other Nix
implementations to drive a modular approach to Nix infrastructure forwards.

Find us at [Contact]({{< ref "/contact" >}})
