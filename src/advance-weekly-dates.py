"""
Append one week to target_end_date and reference_date 
optional lists in the "BDBV 2026 nowcasting and forecasting" round.
"""

import argparse
from datetime import date, timedelta
import json
import os
from pathlib import Path
import re

# Assumptions this script makes: 
# tasks.json input is UTF-8 JSON with no duplicate object keys
# rounds[1] (the second round) is named "BDBV 2026 nowcasting and forecasting", uses reference_date as its round ID, and has round_id_from_variable=true
# that round has exactly one model task, whose required or optional targets include "wk inc confirmed cases"
# both date fields inquestion have nonempty optional lists containing valid YYYY-MM-DD strings, strictly ascending and without duplicates
# date-field objects use literal keys and no nested objects before optional. Multiline arrays place date strings on indented lines

def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"Duplicate JSON key: {key}")
        result[key] = value
    return result


def parse_config(text):
    return json.loads(text, object_pairs_hook=unique_object)


def next_week(values, name):
    if not isinstance(values, list) or not values or any(
        not isinstance(value, str) for value in values
    ):
        raise ValueError(f"{name}.optional must be a nonempty list of YYYY-MM-DD strings")
    dates = []
    for value in values:
        if not re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}", value):
            raise ValueError(f"{name}.optional must contain valid YYYY-MM-DD dates")
        dates.append(date.fromisoformat(value))
    if any(left >= right for left, right in zip(dates, dates[1:])):
        raise ValueError(f"{name}.optional must be sorted and contain no duplicates")
    return (dates[-1] + timedelta(days=7)).isoformat()


def append_optional_date(text, name, addition, expected):
    """Insert into the unique array that produces the expected parsed document."""
    pattern = rf'"{re.escape(name)}"\s*:\s*\{{[^{{}}]*"optional"\s*:\s*(\[[^\[\]]*\])'
    candidates = []
    for match in re.finditer(pattern, text):
        array = match.group(1)
        inside = array[:-1]
        prefix = inside.rstrip()
        closing_space = inside[len(prefix):]
        if "\n" in array:
            indent = re.search(r'\n([ \t]*)"', array)
            if indent is None:
                raise ValueError(f"Could not determine indentation for {name}.optional")
            newline = "\r\n" if "\r\n" in array else "\n"
            separator = "," + newline + indent.group(1)
        else:
            separator = ", "
        replacement = prefix + separator + json.dumps(addition) + closing_space + "]"
        candidate = text[:match.start(1)] + replacement + text[match.end(1):]
        if parse_config(candidate) == expected:
            candidates.append(candidate)
    if len(candidates) != 1:
        raise ValueError(f"Could not uniquely edit second-round {name}.optional")
    return candidates[0]


def advance_weekly_dates(text):
    config = parse_config(text)
    try:
        round_config = config["rounds"][1]
        if round_config["round_name"] != "BDBV 2026 nowcasting and forecasting":
            raise ValueError('The second round must be "BDBV 2026 nowcasting and forecasting"')
        if (
            round_config["round_id"] != "reference_date"
            or round_config["round_id_from_variable"] is not True
        ):
            raise ValueError("The second round must use reference_date as its round ID")
        if len(round_config["model_tasks"]) != 1:
            raise ValueError("Expected exactly one model task in the second round")
        task_ids = round_config["model_tasks"][0]["task_ids"]
        targets = (task_ids["target"].get("required") or []) + (
            task_ids["target"].get("optional") or []
        )
        if "wk inc confirmed cases" not in targets:
            raise ValueError("The second round is not the weekly confirmed-case task")
        additions = {
            name: next_week(task_ids[name]["optional"], name)
            for name in ("reference_date", "target_end_date")
        }
    except (KeyError, IndexError, TypeError) as error:
        raise ValueError("Unexpected configuration structure for the second round") from error

    for name, addition in additions.items():
        task_ids[name]["optional"].append(addition)
        text = append_optional_date(text, name, addition, config)
    return text, additions


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("config", nargs="?", type=Path, default=Path("hub-config/tasks.json"))
    args = parser.parse_args()
    try:
        updated, additions = advance_weekly_dates(args.config.read_bytes().decode("utf-8"))
    except (OSError, UnicodeError, ValueError, OverflowError) as error:
        parser.error(str(error))
    args.config.write_bytes(updated.encode("utf-8"))
    for name, addition in additions.items():
        print(f"Added {name}: {addition}")
    output = os.environ.get("GITHUB_OUTPUT")
    if output:
        with open(output, "a", encoding="utf-8") as stream:
            for name, addition in additions.items():
                stream.write(f"{name}={addition}\n")


if __name__ == "__main__":
    main()
