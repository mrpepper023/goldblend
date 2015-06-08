# goldblend

tiny coffeescript preprocessor for easily creating view classes.

# installation

npm i -g goldblend

# tag

you write a program with coffeescript as *.gold. then, 

```
goldblend yourscript.gold
```

it create yourscript.coffee and yourscript.js.

```
#parameters definition
#all parameters
<<<{routername:router, middleware:logincheck, nocache: no}
#no use middleware, use anticache-code
<<<{middleware:, nocache: yes}

#views definition
<<<classname(req,res,arg1,arg2)
  params['title'] = 'hello world'
  params['author'] = 'me'
  @render @@, params
```

