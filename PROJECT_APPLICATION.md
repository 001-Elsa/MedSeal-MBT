# Project application: verifiable data transformation evidence

| 对应版本 | 0.6.0 | 参赛者 | 韩桢 |
| --- | --- | --- | --- |

## Problem

A data-processing program can produce a plausible output while leaving reviewers unable to answer four basic questions: which input produced each output record, which rules were applied, whether the input changed after planning, and whether another machine can verify the result. Existing data cleaners and converters focus on changing data; this project focuses on making a transformation reviewable and reproducible.

## Proposed deliverable

MedSeal-MBT 0.6.0 provides a portable MoonBit evidence core:

- a declared transformation plan;
- input, rule and output digests;
- per-record source references and changed-field declarations;
- a versioned JSON receipt;
- an independent verifier that rejects stale input, changed plans, changed output and incomplete provenance.

The caller owns the actual transformation. The library does not claim to clean, anonymize, generate, synchronize or publish data.

## Distinction and limits

The project does not claim that digests, provenance or replay are new algorithms. Its intended distinction is the combination of a small domain-neutral API, a portable receipt, record-level provenance and an independent binding check. The current repository audit found adjacent data quality, ETL, de-identification, fixture, snapshot and reference-processing projects; therefore the project must use the claim “no direct equivalent identified in the checked directory snapshot”, not “no similar project exists”.

## Current evidence

`examples/evidence` produces a receipt and verifies it on the native target. The API tests cover successful binding, changed-input rejection, changed-output rejection and plan mismatch rejection. The former DICOM implementation remains a historical compatibility surface and is reported separately from the new core.

## Non-goals

This release does not promise anonymous data, business correctness, compliance, a minimal failing dataset, real-time synchronization or official contest acceptance. Those claims require separate implementation and evidence.


## 公共入口清单

兼容公共入口：`api/authorization`, `api/dicom`, `api/dicom_json`, `api/evidence`, `api/explain`, `api/native`, `api/policy`, `api/quality`, `api/query`, `api/validation`。其中 `api/evidence` 是 0.6.0 新的默认入口，其他入口保留各自的历史或平台边界。
