import re
data = open('C:/temp_ola/com/ola/mapsdk/interfaces/INativeMap.class', 'rb').read()
words = set()
for m in re.finditer(b'[a-zA-Z_$][a-zA-Z_$0-9]*', data):
    word = m.group(0).decode('utf-8', 'ignore')
    if len(word) > 3 and word.isascii():
        words.add(word)
print(", ".join(sorted(list(words))))
