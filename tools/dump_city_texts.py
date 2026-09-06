import UnityPy, re

env = UnityPy.load(r'D:\SteamLibrary\steamapps\common\Security 51\Security51_Data\sharedassets5.assets')
f = list(env.files.values())[0]

env_ggm = UnityPy.load(r'D:\SteamLibrary\steamapps\common\Security 51\Security51_Data\globalgamemanagers.assets')
f_ggm = list(env_ggm.files.values())[0]
scripts = {}
for obj in f_ggm.objects.values():
    if obj.type.name == 'MonoScript':
        try:
            ms = obj.read()
            scripts[obj.path_id] = ms.m_Name
        except:
            pass

def get_comp_name(c):
    if c.type.name != 'MonoBehaviour':
        return c.type.name
    try:
        d = c.read_typetree(check_read=False)
        s = d.get('m_Script')
        if s and s.get('m_PathID') in scripts:
            return scripts[s['m_PathID']]
    except:
        pass
    return 'MonoBehaviour'

results = []
def check_node(tr_obj, path=''):
    go = f.objects[tr_obj.m_GameObject.path_id].read()
    current_path = path + '/' + go.m_Name
    comps = [get_comp_name(f.objects[c.path_id]) for c in go.m_Components]
    for c in go.m_Components:
        c_obj = f.objects[c.path_id]
        c_name = get_comp_name(c_obj)
        if 'Text' in c_name:
            raw = c_obj.get_raw_data()
            try:
                d = c_obj.read_typetree(check_read=False)
                txt = d.get('m_text', d.get('m_Text', ''))
            except:
                txt = 'ERR'
            results.append((current_path, c_name, txt, comps))
    for ch_ptr in tr_obj.m_Children:
        check_node(f.objects[ch_ptr.path_id].read(), current_path)

for obj in f.objects.values():
    if obj.type.name == 'GameObject':
        go = obj.read()
        if go.m_Name == 'CityWindow':
            for c in go.m_Components:
                c_obj = f.objects[c.path_id]
                if 'Transform' in c_obj.type.name:
                    check_node(c_obj.read())

for r in results:
    print(f'{r[0]} | {r[1]} | text="{r[2]}" | all_comps={r[3]}')
