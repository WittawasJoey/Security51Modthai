import UnityPy, os, re

game_data = r'D:\SteamLibrary\steamapps\common\Security 51\Security51_Data'
for fname in sorted(os.listdir(game_data)):
    if not (fname.endswith('.assets') or fname.startswith('level')): continue
    fpath = os.path.join(game_data, fname)
    if not os.path.isfile(fpath): continue
    try:
        env = UnityPy.load(fpath)
        f = list(env.files.values())[0]
        for obj in f.objects.values():
            if obj.type.name == 'GameObject':
                go = obj.read()
                for c in go.m_Components:
                    c_obj = f.objects[c.path_id]
                    if c_obj.type.name == 'MonoBehaviour':
                        raw = c_obj.get_raw_data()
                        if b'Button\x00' in raw or b'\x06\x00\x00\x00Button' in raw:
                            p_name = 'NONE'
                            try:
                                tr = f.objects[go.m_Components[0].path_id].read()
                                if tr.m_Father.path_id != 0:
                                    p_name = f.objects[tr.m_Father.read().m_GameObject.path_id].read().m_Name
                            except:
                                pass
                            print(f'[{fname}] GO: "{go.m_Name}", Parent: "{p_name}"')
    except Exception as e:
        print(f'Err {fname}: {e}')
