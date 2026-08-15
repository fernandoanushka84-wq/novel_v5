from pathlib import Path
p=Path(r'c:\lakmal_code\novel_mobile_app\lib\ui\screens\discover_screen.dart')
s=p.read_text(encoding='utf-8')
print('file:',p)
print('LBRACE',s.count('{'),'RBRACE',s.count('}'),'LPAREN',s.count('('),'RPAREN',s.count(')'))
# show last 200 chars
print('\n--- tail ---')
print(s[-400:])
