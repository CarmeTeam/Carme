import re

password_criteria = """
<h5 class="mb-2">Password criteria</h5>
<ul class="mb-2">
    <li>must have a length of at least 25 characters</li>
    <li>contains neither your account name nor parts of your full name that exceed two consecutive
        characters</li>
    <li>contains characters from three of the following four categories:<br>
        - English uppercase characters (A through Z)<br>
        - English lowercase characters (a through z)<br>
        - Base 10 digits (0 through 9)<br>
        - Non-alphanumeric characters (for example, :, #, %)</li>
</ul>
"""

def check_password(pw1, pw2):
    # check results
    valid_length = len(pw1) >= 25  # length
    valid_equality = pw1 == pw2 # equality

    char_types = []
    char_types.append(re.search(r"[0-9]", pw1) is not None)  # digits
    char_types.append(re.search(r"[A-Z]", pw1) is not None)  # uppercase
    char_types.append(re.search(r"[a-z]", pw1) is not None)  # lowercase
    char_types.append(re.search(r"[^0-9a-zA-Z]", pw1) is not None) # other

    valid_chars = sum(char_types) >= 3 # character types
    
    # whether the password passed all checks
    return valid_length and valid_equality and valid_chars

