"""Small independent reference model for enterprise job state transitions."""
from dataclasses import dataclass

STATES = (
    "CREATED", "INGESTED", "PLANNED", "RUNNING", "VALIDATING", "AWAITING_REVIEW",
    "READY", "PUBLISHING", "PUBLISHED", "ACKNOWLEDGED", "CANCELLED", "FAILED",
)

ALLOWED = {
    "CREATED": {"CREATED", "INGESTED", "FAILED"},
    "INGESTED": {"PLANNED", "FAILED"},
    "PLANNED": {"RUNNING", "CANCELLED", "FAILED"},
    "RUNNING": {"VALIDATING", "CANCELLED", "FAILED"},
    "VALIDATING": {"AWAITING_REVIEW", "CANCELLED", "FAILED"},
    "AWAITING_REVIEW": {"READY", "CANCELLED", "FAILED"},
    "READY": {"PUBLISHING", "CANCELLED", "FAILED"},
    "PUBLISHING": {"PUBLISHED", "FAILED"},
    "PUBLISHED": {"PUBLISHED", "ACKNOWLEDGED"},
    "ACKNOWLEDGED": {"ACKNOWLEDGED"},
    "CANCELLED": {"CANCELLED"},
    "FAILED": {"FAILED", "CANCELLED"},
}


@dataclass
class Model:
    state: str = "CREATED"
    reviewed: bool = False
    signed: bool = False
    release_authorized: bool = False
    objects: int = 0

    def apply(self, target, *, review=False, signed=False, authorize=False, objects=None):
        if target not in STATES or target not in ALLOWED[self.state]:
            raise ValueError(f"illegal-transition:{self.state}->{target}")
        if target in {"PUBLISHING", "PUBLISHED", "ACKNOWLEDGED"} and not self.reviewed:
            raise ValueError("release-before-review")
        if target in {"PUBLISHED", "ACKNOWLEDGED"} and not self.signed:
            raise ValueError("release-before-signature")
        if authorize and not (self.reviewed and self.signed):
            raise ValueError("authorization-without-evidence")
        if objects is not None and objects < 0:
            raise ValueError("negative-object-count")
        self.state = target
        self.reviewed = self.reviewed or review
        self.signed = self.signed or signed
        self.release_authorized = self.release_authorized or authorize
        if objects is not None:
            self.objects = objects
        return self


def assert_invariants(model):
    if model.release_authorized and (not model.reviewed or not model.signed):
        raise AssertionError("authorized-without-review-and-signature")
    if model.state in {"PUBLISHED", "ACKNOWLEDGED"} and not model.signed:
        raise AssertionError("visible-release-without-signature")
    if model.objects < 0:
        raise AssertionError("negative-object-count")
