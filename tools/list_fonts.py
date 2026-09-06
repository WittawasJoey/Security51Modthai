import UnityPy, os

game_data = r'D:\SteamLibrary\steamapps\common\Security 51\Security51_Data'
for fname in sorted(os.listdir(game_data)):
    if not (fname.endswith('.assets') or fname.startswith('level')): continue
    fpath = os.path.join(game_data, fname)
    if not os.path.isfile(fpath): continue
    try:
        env = UnityPy.load(fpath)
        f = list(env.files.values())[0]
        for obj in f.objects.values():
            if obj.type.name == 'MonoBehaviour':
                raw = obj.get_raw_data()
                if b'm_CharacterTable' in raw or b'characterTable' in raw or b'TMP_FontAsset' in raw:
                    try:
                        d = obj.read_typetree(check_read=False)
                        name = d.get('m_Name', '')
                        print(f'[{fname}] FontAsset: "{name}"')
                    except:
                        pass
    except Exception as e:
        pass
