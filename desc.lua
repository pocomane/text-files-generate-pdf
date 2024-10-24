
{
  output = {
    { 'a5.html', 'example/hello_world.md' },
    { 'a5-twocol.html', 'example/hello_world.md', section_decoration=true },
    { 'a4.html', 'example/hello_world.md', section_decoration=true, content='<div style="page-break-after: always;" /><img style="width: 100%;" src="../example/star.svg" />' },
    { 'a5.html', 'example/hello_world.md', add_front_page=true, insert_image=true, },
    { 'a5-twocol.html', 'example/hello_world.md', add_front_page=true, insert_image=true, },
  },
  path = {
   build = "./build",
  },
  title = {
    text = "TheTitle",
    author = "by Author",
    image = "../example/star.svg",
  },
  section_pre = {
     ['## Subsection'] = '</div><div>',
  },
  section_image = {
     ['# SECTION'] = '../example/star.svg',
  },
  snippet = {
    font = "../gentium.ttf",
  },
}

