// Read-only project inspection in a dedicated After Effects instance.
// Does not run the pack's scripts, expressions, crack or activation helpers.
(function () {
  if (app.project && (app.project.file || app.project.numItems > 0))
    throw new Error('Existing project open; inspection aborted.');
  var root = new Folder('C:/Users/SnyX/Downloads/Compressed/Handy Seamless Transitions v5.1/HST_v5.1');
  var out = new Folder(new File($.fileName).parent.parent.fsName + '/tmp/hst-audit');
  out.create();
  function quote(s) { return '"' + String(s).replace(/\\/g,'\\\\').replace(/"/g,'\\"').replace(/\r/g,'\\r').replace(/\n/g,'\\n').replace(/\t/g,'\\t') + '"'; }
  function json(x) {
    if (x === null || x === undefined) return 'null';
    if (typeof x === 'string') return quote(x);
    if (typeof x === 'number') return isFinite(x) ? String(x) : 'null';
    if (typeof x === 'boolean') return String(x);
    var a=[], k;
    if (x instanceof Array) { for(k=0;k<x.length;k++) a.push(json(x[k])); return '['+a.join(',')+']'; }
    for(k in x) if(x.hasOwnProperty(k)) a.push(quote(k)+':'+json(x[k]));
    return '{'+a.join(',')+'}';
  }
  function write(name, value) { var f=new File(out.fsName+'/'+name);f.encoding='UTF-8';f.open('w');f.write(json(value));f.close(); }
  var files=[];
  function visit(folder) { var entries=folder.getFiles(); for(var i=0;i<entries.length;i++) {
    if(entries[i] instanceof Folder) visit(entries[i]);
    else if(/\.aep$/i.test(entries[i].name)) files.push(entries[i]);
  }}
  visit(root); files.sort(function(a,b){return a.fsName<b.fsName?-1:1;});
  function simple(value) {
    if(value===null || value===undefined)return null;
    if(typeof value==='number' || typeof value==='string' || typeof value==='boolean')return value;
    if(value instanceof Array){var a=[];for(var i=0;i<value.length;i++)a.push(simple(value[i]));return a;}
    // Host objects (TextDocument, custom plugin data) are not plain JSON and
    // can contain cyclic engine handles. Never enumerate those handles.
    return null;
  }
  function property(p, depth) {
    if(depth>12) return null;
    var r={name:p.name,match:p.matchName,index:p.propertyIndex};
    if(p.propertyType !== PropertyType.PROPERTY) {
      r.children=[];for(var j=1;j<=p.numProperties;j++) r.children.push(property(p.property(j),depth+1));
    } else {
      try { r.value=simple(p.valueAtTime(0,true)); } catch(e) { r.error=String(e); }
      try { if(p.expression) r.expression=p.expression; } catch(e) {}
      r.keys=[];
      for(var k=1;k<=p.numKeys;k++) {
        var key={time:p.keyTime(k),value:simple(p.keyValue(k))};
        try {
          key.inType=String(p.keyInInterpolationType(k));key.outType=String(p.keyOutInterpolationType(k));
          key.inEase=[];key.outEase=[];
          var a=p.keyInTemporalEase(k),b=p.keyOutTemporalEase(k);
          for(var z=0;z<a.length;z++)key.inEase.push([a[z].speed,a[z].influence]);
          for(var z=0;z<b.length;z++)key.outEase.push([b[z].speed,b[z].influence]);
        } catch(e) {}
        r.keys.push(key);
      }
    }
    return r;
  }
  app.beginSuppressDialogs();
  try {
    for(var n=0;n<files.length;n++) {
      var destination=new File(out.fsName+'/'+n+'.json');
      if(destination.exists && destination.length>0)continue;
      write('progress.json',{index:n,total:files.length,path:files[n].fsName});
      var result={path:files[n].fsName,compositions:[]};
      try {
        app.open(files[n]);
        for(var c=1;c<=app.project.numItems;c++) {
          var item=app.project.item(c);if(!(item instanceof CompItem))continue;
          var comp={id:item.id,name:item.name,width:item.width,height:item.height,duration:item.duration,fps:item.frameRate,layers:[]};
          for(var l=1;l<=item.numLayers;l++) {
            var layer=item.layer(l),desc={name:layer.name,index:l,inPoint:layer.inPoint,outPoint:layer.outPoint,startTime:layer.startTime,enabled:layer.enabled,properties:[]};
            try { desc.sourceId=layer.source.id;desc.parent=layer.parent?layer.parent.index:null;desc.blend=String(layer.blendingMode);desc.adjustment=layer.adjustmentLayer;desc.threeD=layer.threeDLayer; } catch(e) {}
            for(var p=1;p<=layer.numProperties;p++)desc.properties.push(property(layer.property(p),0));
            comp.layers.push(desc);
          }
          result.compositions.push(comp);
        }
      } catch(e) {result.error=String(e);}
      write(n+'.json',result);
      if(app.project)app.project.close(CloseOptions.DO_NOT_SAVE_CHANGES);
    }
    write('progress.json',{complete:true,total:files.length});
  } finally { app.endSuppressDialogs(false); }
})();
