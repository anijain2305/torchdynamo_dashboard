import dataclasses


@dataclasses.dataclass
class LogInfo:
    # Day of the year this log was generated
    day: str

    # Directory path where all logs are present
    dir_path: str
