#!/usr/bin/env coffee

fs = require('fs')
path = require('path')





#------------------------------------
#-- Scan Files
dirfiles = (dirpath, regex, next) ->
  fnames = []
  console.log 'scanning in '+dirpath
  fs.readdir dirpath, (err, files) ->
    if (err) 
      console.log err
      throw err
    files.forEach (fname) ->
      if regex.test(fname)
        if (fs.statSync dirpath+'/'+fname).isFile()
          fnames.push(fname)
    next(fnames)

#------------------------------------
#-- Create Test Views
createviewstester = (viewengine) ->
  if fs.existsSync 'testviews.coffee'
    code = fs.readFileSync 'testviews.coffee'
    code = code.toString().split("\n")
  else
    code = [
      'fragmenttest = (router) ->'
      ''
      '  fs = require('+"'"+'fs'+"'"+')'
      ''
      '  #<<<cases'
      '  #<<<cases'
      ''
      'module.exports.fragmenttest = fragmenttest'
    ]
  #解析viewsの中身
  templates = []
  usercodes = {}
  mode = 'global'
  for line in code
    switch mode
      when 'global'
        if line == '  #<<<cases'
          mode = 'views'
      when 'views'
        if line == '  #<<<cases'
          mode = 'global'
        else
          if /^  #<<<__/.test line
            mode = 'template'
            result = line.match(/^  #<<<(\S+)/)
            nowtemplate = result[1]
            templates.push nowtemplate
            usercodes[nowtemplate] ?= {}
            usercodes[nowtemplate]['exist'] = false
      when 'template'
        if /^  #<<<__/.test line
          mode = 'views'
        else
          if /^    #<<<user/.test line
            mode = 'usercode'
      when 'usercode'
        if /^    #<<<user/.test line
          mode = 'template'
        usercodes[nowtemplate]['lines'] = []
        usercodes[nowtemplate]['lines'].push(line)
      else
  
  #viewsを見て、templatesを補う＆usercodes.templname.exist = trueにする
  dirfiles __dirname + '/views',(new RegExp('^__.*\.'+viewengine+'$')), (fnames) ->
    for fname in fnames
      fname = fname.replace(/\.[^.]+$/,'')
      templates.push(fname)
      usercodes[fname] ?= {}
      usercodes[fname]['exist'] = true
    
    #さあ、構築だ
    resultcode = []
    mode = 'global'
    for line in code
      switch mode
        when 'global'
          if line == '  #<<<cases'
            mode = 'views'
          resultcode.push(line)
        when 'views'
          if line == '#deprecated'
          
          else if line == '  #<<<cases'
            #ここで残りの分を吐き出す
            for selectone in templates
              if usercodes[selectone].ok?
              else
                resultcode.push ''
                resultcode.push "  router.get '/#{selectone}',(req,res) ->"
                resultcode.push '    params = req.query ? {}'
                resultcode.push '    #<<<user'
                resultcode.push '    #<<<user'
                resultcode.push "    res.render '#{selectone}', params"
                resultcode.push ''
            mode = 'global'
            resultcode.push(line)
          else
            if /^  #<<<__/.test line
              mode = 'template'
              result = line.match(/^  #<<<(\S+)/)
              nowtemplate = result[1]
              usercodes[nowtemplate]['ok'] = true
              if not usercodes[nowtemplate].exist
                resultcode.push '#deprecated'
            resultcode.push(line)
        when 'template'
          if /^  #<<<__/.test line
            #ここで一気に吐き出し
            resultcode.push ''
            resultcode.push "  router.get '/#{nowtemplate}',(req,res) ->"
            resultcode.push '    params = req.query ? {}'
            resultcode.push '    #<<<user'
            for str in usercodes[nowtemplate].lines
              resultcode.push str
            resultcode.push '    #<<<user'
            resultcode.push "    res.render '#{nowtemplate}', params"
            resultcode.push ''
            resultcode.push(line)
            mode = 'views'
          else
            if /^    #<<<user/.test line
              mode = 'usercode'
            #読み飛ばし
        when 'usercode'
          if /^    #<<<user/.test line
            mode = 'template'
          #読み飛ばし
        else
    
    fs.writeFileSync 'testviews.coffee',resultcode.join("\n")




#------------------------------------
#-- 成果物のjsへのコンパイル
coffee = require('coffee-script').compile

compile = (filedst) ->
  read = fs.readFileSync filedst,'utf8'
  shebang = read.match(/^#!.*\r?\n/)
  if shebang?
    shebang = shebang[0]
    read = read.replace(shebang,'')
    shebang = shebang.replace('coffee','node')
  jssrc = coffee read.toString(),{bare:true}
  if shebang?
    jssrc = shebang+"\n"+jssrc
    compiled = filedst.replace(/\.coffee$/,'')
  else
    compiled = filedst.replace(/coffee$/,'js')
  fs.writeFileSync compiled,jssrc,'utf8'
  if shebang?
    oldmask = process.umask 0
    fs.chmodSync compiled,0o0755
    process.umask oldmask


#------------------------------------
#-- テンプレートファイルのコピー
filecopy = (classname,cvparams,viewengine) ->
  docopy = false
  filename = 'views/'+classname+'.'+viewengine
  template = 'views/__template.'+viewengine

  cv = cvparams.replace /^\s*,/, ''
  switch viewengine
    when 'ect'
      regex = /^<!--update/
      text = "<!--update:この行を消さないと、毎回上書きされます-->\n"
      text += "<!--このテンプレートの自明な引数 ⇒ #{cv} -->\n"
    when 'jade'
      regex = /^\/\/update/
      text = "//update:この行を消さないと、毎回上書きされます\n"
      text += "//このテンプレートの自明な引数 ⇒ #{cv}\n"
    when 'ejs'
      regex = /^<% \/\* update/
      text = "<% /* update:この行を消さないと、毎回上書きされます */ %>\n"
      text += "<% /* このテンプレートの自明な引数 ⇒ #{cv} */ %>\n"
    when 'coffee'
      regex = /^#update/
      text = "#update:この行を消さないと、毎回上書きされます\n"
      text += "#このテンプレートの自明な引数 ⇒ #{cv}\n"
    when 'haml'
      regex = /^-#update/
      text = "-#update:この行を消さないと、毎回上書きされます\n"
      text += "-#このテンプレートの自明な引数 ⇒ #{cv}\n"
    else
      console.log 'view engine ['+viewengine+'] is mi ta i o u!'
      return
  
  if not fs.existsSync template
    console.log 'template file is not found!'
    return
  if fs.existsSync filename
    if regex.test fs.readFileSync(filename).toString()
      #コピー先が上書き許可なので、コピーする
      docopy = true
      fs.unlinkSync filename
    else
      #コピー先が有効なので、コピーしない
      docopy = false
  else
    #コピー先が存在しないので、コピーする
    docopy = true
    
  if docopy
    fs.writeFileSync(filename, text+fs.readFileSync(template, 'utf8'))
    console.log 'created: '+filename


#------------------------------------
#-- ファイル書き出し
writetext = (dst, text) ->
  fs.appendFileSync dst,text,'utf8', (err) -> console.log err


#------------------------------------
#-- 画面定義の出力（末尾）
generateTail = (dst, indentsp, classname, routername) ->
  text = indentsp+classname+'.install '+routername+"\n\n"
  text = indentsp+'module.exports.'+classname+' = '+classname+"\n\n"
  writetext dst,text

#------------------------------------
#-- 画面定義の出力（前半）
generateMain = (dst,indentsp,classname,temp,routername,mw,nocache,viewengine) ->
  args = []
  for str,index in temp
    str = str.replace(/^\s+/, '').replace(/\s+$/, '')
    switch index
      when 0
        argreq = str
      when 1
        argres = str
      else
        args.push str
  urlprm = ''
  cvparams = ''
  buildparams4sp = ''
  reqparams4sp = ''
  yamlparams6sp = ''

  for str,index in args
    urlprm += '/:'+str
    cvparams += ','+str
    if index>0
      buildparams4sp += "\n"
      reqparams4sp += "\n"
      yamlparams6sp += "\n"
    buildparams4sp += "#{indentsp}    params += '/'+encodeURIComponent(#{str})"
    reqparams4sp += "#{indentsp}    #{str} = #{argreq}.params.#{str} ? ''"
    yamlparams6sp += "#{indentsp}      #{str}: #{str}"
  emptyobject = if args.length == 0 then ' {}' else ''

  randomstring = 'Math.random().toString(36).slice(-8)'
  appendnocache = if nocache then "+'?'+#{randomstring}+#{randomstring}" else ''
  path = classname.replace /__/,'/'
  
  text = """
#{indentsp}#{classname} = class _#{classname}
#{indentsp}  @install: (obj) => obj.get '/#{path}#{urlprm}',#{mw}@get
#{indentsp}  @redirect: (#{argreq},#{argres}#{cvparams}) =>
#{indentsp}    params = ''
#{buildparams4sp}
#{indentsp}    #{argres}.redirect '/#{path}'+params#{appendnocache}
#{indentsp}  @get: (#{argreq},#{argres}) =>
#{reqparams4sp}
#{indentsp}    @direct #{argreq},#{argres}#{cvparams}
#{indentsp}  @direct: (#{argreq},#{argres}#{cvparams}) =>
#{indentsp}    params =#{emptyobject}
#{yamlparams6sp}
"""
  writetext dst,text
  if filesw?
    filecopy classname,cvparams,viewengine
  return argres


#------------------------------------
#-- トークンの発見と処理
doconv = (dst, src) ->
  console.log 'processing... '+src
  content = fs.readFileSync(src).toString()
  content = content.replace(/\r\n/, "\n").replace(/\r/, "\n").split("\n")
  if fs.existsSync(dst)
    fs.writeFile dst, '', 'utf8', (err) -> console.log err
  comments = false
  generate = false
  indentsp = ''
  defaultmode = true
  routername = 'router'
  mw = ''
  nocache = true
  viewengine = 'ect'
  for line,index in content
    if index>0
      writetext dst,"\n"
    if comments
      if generate
        writetext dst,'  '+line
      else
        writetext dst,line
      if /^\s*###/.test(line)
        comments = false
    else
      normaloutput = false
      addindent = false
      
      result = line.match /^(\s*)#(\s*)/
      if result == null
        comsp = 0
        linecom = false
      else
        comsp = result[1].length+result[2].length
        linecom = true
      
      if /^\s*###/.test(line) #コメントのみ行を影響させない
        comments = true
        normaloutput = true
        addindent = generate
      else if linecom and ((not generate) or (comsp > indentsp.length))
        #コメント行は、コメントアウトと見なされる限りは無視
        normaloutput = true
        addindent = generate
      else if /^\s*$/.test(line) #空行を影響させない
        normaloutput = true
        addindent = generate
      else
        if /^\s*<<</.test(line)
          if generate
            #generate末尾出力
            generateTail dst,indentsp,classname,routername

          result = line.match /^(\s*)<<<\s*{([^{}]*)}/
          if result == null
            #newgenerate
            if defaultmode
              defaultmode = false
              confcomment = '#'+routername+', '
              confcomment += mw.replace(/,$/,'')+', '
              confcomment += nocache.toString()+', '
              confcomment += viewengine
              writetext dst,confcomment
            
            #indentspの取得
            #argreq,argres,argsの取得
            #classnameの取得
            result = line.match /^(\s*)<<<\s*(\S+)\s*\(([^()]+)\)/
            if result == null
              console.log 'syntax error ['+index+']'
              process.exit 1
            #generate要素読み取り
            indentsp = result[1]
            classname = result[2]
            temp = result[3].split(',')
            argres = generateMain dst,indentsp,classname,temp,routername,mw,nocache,viewengine
            generate = true
            normaloutput = false
          else
            #routernameの取得
            #mwの取得
            #nocache
            defaultmode = false
            scopeindentsp = result[1]
            tempkv = {}
            keyvalues = result[2].split(',')
            for keyvalue in keyvalues
              keyvalue = keyvalue.replace(/^\s+/, '').replace(/\s+$/, '')
              keyvalue = keyvalue.split(':')
              key = keyvalue[0].replace(/^\s+/, '').replace(/\s+$/, '')
              value = keyvalue[1].replace(/^\s+/, '').replace(/\s+$/, '')
              tempkv[key] = value
            if tempkv.routername?
              routername = tempkv.routername
              if routername.length == 0
                routername = 'router'
            if tempkv.middleware?
              mw = tempkv.middleware
              if mw.length > 0
                mw = mw + ','
            if tempkv.viewengine
              viewengine = tempkv.viewengine
              if viewengine == ''
                viewengine = 'ect'
            if tempkv.nocache?
              nocache = (/(true|ok|yes)/i.test(tempkv.nocache))
            confcomment = '#'+routername+', '
            confcomment += mw.replace(/,$/,'')+', '
            confcomment += nocache.toString()+', '
            confcomment += viewengine
            writetext dst,confcomment
            normaloutput = false
        else if generate
          spaces = line.match /^\s*/
          if spaces == null
            console.log 'a ri e nai error!'
            process.exit()
          if spaces[0].length > indentsp.length
            #generateスコープ内出力
            line = line.replace /@render\b/, argres+'.render'
            line = line.replace /@@/, "'"+classname+"'"
            writetext dst,'  '+line
            normaloutput = false
          else
            #generate末尾出力
            generateTail dst,indentsp,classname,routername
            generate = false
            normaloutput = true
        else
          normaloutput = true
      
      if normaloutput
        if addindent
          fs.appendFileSync dst,'  '+line,'utf8', (err) -> console.log err
        else
          fs.appendFileSync dst,line,'utf8', (err) -> console.log err
  console.log 'completed!'
  if testersw?
    createviewstester(viewengine)


#------------------------------------
#-- コマンドライン引数の解釈
options = false
for val,index in process.argv
  itsself = false
  if index == 1 and /\/goldblend\.coffee$/.test(val)
    compile val
    itsself = true
  if index > 0
    if /^-/.test(val)
      allflag = /a/.test(val) or /^\-\-all$/.test(val)
      
      if /w/.test(val) or /^\-\-watch$/.test(val)
        options = true
        watch = true
      if /c/.test(val) or /^\-\-compile$/.test(val) or allflag
        options = true
        compilesw = true
      if /t/.test(val) or /^\-\-testview$/.test(val) or allflag
        options = true
        testersw = true
      if /f/.test(val) or /^\-\-file$/.test(val) or allflag
        options = true
        filesw = true
      if /v/.test(val) or /^\-\-version$/.test(val)
        options = true
        console.log 'version 0.2'
        process.exit 0
      if /h/.test(val) or /^\-\-help$/.test(val)
        options = false
    else
      if /\.gold$/i.test(val) and (fs.existsSync val) and (not itsself)
        options = true
        filesrc = val
        filedst = val.replace /gold$/i, 'coffee'

if not options
  console.log '''
CoffeeScript version
  coffee goldblend.coffee -e [options] [filepath]

Javascript version
  goldblend [options] [filepath]
  
  -v --version  show version
  -h --help     show usage
  -w --watch    watch source file
  -c --compile  compile source file
  -t --testview create 'testviews.coffee' for testing 
                template files (__[filename].[ext]) in /views.
  -f --file     create view template files by copying 
                '/views/__template.[ext]'
  -a --all      same as -ctf
  filepath      source file name.
'''
  process.exit 0

if not(filesrc?)
  if testersw?
    createviewstester('ect')
else

  #------------------------------------
  #-- メインルーチン
  if compilesw?
    doconv filedst,filesrc
    compile filedst

  if watch?
    fs.watch filesrc, (event, filename) ->
      if (filename)
        if compilesw?
          doconv filedst,filename
          compile filedst

0
