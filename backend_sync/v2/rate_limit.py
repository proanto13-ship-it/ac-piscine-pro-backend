from collections import defaultdict, deque
from dataclasses import dataclass
from math import ceil
from threading import Lock
from time import monotonic


@dataclass(frozen=True)
class RateLimitRule:
    name: str
    limit: int
    window_seconds: int


class InMemoryRateLimiter:
    def __init__(self):
        self._events: dict[str, deque[float]] = defaultdict(deque)
        self._lock = Lock()

    def check(self, key: str, rule: RateLimitRule) -> tuple[bool, int]:
        if rule.limit <= 0 or rule.window_seconds <= 0:
            return True, 0

        now = monotonic()
        threshold = now - rule.window_seconds
        with self._lock:
            bucket = self._events[key]
            while bucket and bucket[0] <= threshold:
                bucket.popleft()
            if len(bucket) >= rule.limit:
                retry_after = max(1, ceil(rule.window_seconds - (now - bucket[0])))
                return False, retry_after
            bucket.append(now)
        return True, 0
