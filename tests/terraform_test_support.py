"""Helpers for isolating temporary Terraform configurations from remote state."""

import re


def without_cloud_backend(configuration):
    """Remove one terraform.cloud block, including nested workspace settings.

    Tokenize braces separately from strings and comments so their contents
    cannot truncate the block or accidentally remove other Terraform settings.
    The caller writes only a temporary test copy, never the checked-in source.
    """
    pattern = re.compile(
        r'(?P<comment>//[^\n]*|\#[^\n]*|/\*.*?\*/)'
        r'|(?P<string>"(?:\\.|[^"\\])*")'
        r'|(?P<word>[A-Za-z_][A-Za-z_0-9-]*)'
        r'|(?P<brace>[{}])',
        re.S,
    )
    tokens = [match for match in pattern.finditer(configuration)
              if match.lastgroup != "comment"]
    depth = 0
    terraform_block = False
    spans = []
    start = None
    for index, token in enumerate(tokens):
        value = token.group()
        if value == "{" and depth == 0:
            terraform_block = index > 0 and tokens[index - 1].group() == "terraform"
        if (value == "cloud" and terraform_block and depth == 1
                and index + 1 < len(tokens) and tokens[index + 1].group() == "{"):
            start = token.start()
        if value == "{":
            depth += 1
        elif value == "}":
            depth -= 1
            if start is not None and depth == 1:
                spans.append((start, token.end()))
                start = None
            if depth == 0:
                terraform_block = False
    if depth != 0 or start is not None or len(spans) != 1:
        raise AssertionError("Could not isolate exactly one Terraform Cloud block")
    start, end = spans[0]
    return configuration[:start] + configuration[end:]
