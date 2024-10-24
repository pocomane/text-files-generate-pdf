
{
  output = {
    { 'a5.html', './hello_world.md' },
    { 'a5-twocol.html', './hello_world.md', section_decoration=true },
    { 'a4.html', './hello_world.md', section_decoration=true, content='<div style="page-break-after: always;" /><img style="width: 100%;" src="../image.svg" />' },
    { 'a5.html', './hello_world.md', add_front_page=true, insert_image=true, },
    { 'a5-twocol.html', './hello_world.md', add_front_page=true, insert_image=true, },
  },
  path = {
   build = "./build",
  },
  title = {
    text = "TheTitle",
    author = "by Author",
    image = "../image.svg",
  },
  section_pre = {
     ['## Subsection'] = '</div><div>',
  },
  section_image = {
     ['# SECTION'] = '../image.svg',
  },
  snippet = {
    font = "../gentium.ttf",
  },
}

