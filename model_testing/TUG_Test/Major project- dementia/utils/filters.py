from collections import deque

class MajorityFilter:
    def __init__(self, maxlen, majority_count):
        self.buffer = deque(maxlen=maxlen)
        self.majority_count = majority_count

    def update(self, value):
        self.buffer.append(value)

    def get_majority(self):
        for status in set(self.buffer):
            if self.buffer.count(status) >= self.majority_count:
                return status
        return None