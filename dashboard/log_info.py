import dataclasses
from datetime import datetime


@dataclasses.dataclass
class LogInfo:
    # Day of the year this log was generated
    day: str

    # Directory path where all logs are present
    dir_path: str


def get_date(log_info):
    return datetime.strptime(f"{log_info.day}", "%j").strftime("%m-%d")
