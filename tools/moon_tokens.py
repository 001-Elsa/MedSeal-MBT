"""Ignore formatter trivia while preserving all string and byte literal values."""
import re


def semantic_tokens(text):
    # Match literals first: their whitespace/comments are meaningful.
    tokens = re.findall(r'"(?:\\.|[^"\\])*"|//[^\n]*|[A-Za-z_0-9]+|\S', text)
    return tuple(token for index, token in enumerate(tokens)
                 if not token.startswith('//') and token != ';'
                 and not (token == ',' and index + 1 < len(tokens) and tokens[index + 1] in {')', ']', '}'}))
