import re

def check_password(pw1, pw2):
    # check results
    valid_length = len(pw1) >= 13  # length
    valid_equality = pw1 == pw2 # equality

    char_types = []
    char_types.append(re.search(r"[0-9]", pw1) is not None)  # digits
    char_types.append(re.search(r"[A-Z]", pw1) is not None)  # uppercase
    char_types.append(re.search(r"[a-z]", pw1) is not None)  # lowercase
    char_types.append(re.search(r"[^0-9a-zA-Z]", pw1) is not None) # other

    valid_chars = sum(char_types) >= 3 # character types
    
    # whether the password passed all checks
    return valid_length and valid_equality and valid_chars
