import json

with open('user_requests_today.jsonl', 'r', encoding='utf-16') as f:
    for i, line in enumerate(f):
        try:
            data = json.loads(line)
            content = data.get('content', '')
            if '<USER_REQUEST>' in content:
                req = content.split('<USER_REQUEST>')[1].split('</USER_REQUEST>')[0].strip()
                print(f"Request {i+1}:\n{req}\n{'-'*40}")
        except Exception as e:
            pass
