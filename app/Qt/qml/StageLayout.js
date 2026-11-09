// SPDX-License-Identifier: AGPL-3.0-only
// Ported from nya-owo/cloudy ui_stage.go and ui_stage_styles.go at 250da6d.
// Qt layout/measurement adapter, 2026-11-08. See licenses/cloudy/SOURCE.md.
.pragma library

function clamp(v) { return Math.max(0, Math.min(1, v)); }
function mix(a, b, t) { return a + (b - a) * t; }
function random(seed, offset) { var x = Math.sin(seed + offset) * 10000; return x - Math.floor(x); }
function spring(t) { return t <= 0 ? 0 : 1 - Math.exp(-10 * t) * (Math.cos(10 * t) + Math.sin(10 * t)); }
function cubic(t) { t = clamp(t); return 1 - Math.pow(1 - t, 3); }
function chars(text) { return Array.from(String(text)); }
function mark(c) { return /[\s.,!?;:，。！？、；：…「」『』（）()\[\]“”"'’\-—]/.test(c); }
function length(words) { return words.reduce(function(n, w) { return n + chars(w.text.trim()).length; }, 0); }
function units(words) {
    var result = [], from = 0;
    function phrase(a, b) {
        var count = b - a <= 6 ? 1 : Math.ceil((b - a) / 4);
        for (var k = 0; k < count; ++k)
            result.push([a + Math.floor((b - a) * k / count), a + Math.floor((b - a) * (k + 1) / count)]);
    }
    for (var i = 0; i < words.length; ++i) {
        var text = chars(words[i].text);
        if (i === from && result.length && text.every(mark)) { result[result.length - 1][1] = i + 1; from = i + 1; continue; }
        var last = text[text.length - 1] || "";
        if (i + 1 === words.length || (mark(last) && "'’-".indexOf(last) < 0)) { phrase(from, i + 1); from = i + 1; }
    }
    return result;
}
function space(shapes, widths, gap) {
    for (var i = 0; i < shapes.length; ++i) {
        var grow = widths[i] * (shapes[i].scale * 1.4 - 1) / 2;
        var next = i + 1 < shapes.length ? widths[i + 1] * (shapes[i + 1].scale * 1.4 - 1) / 2 : 0;
        var toward = i + 1 < shapes.length ? shapes[i].x - shapes[i + 1].x : 0;
        shapes[i].margin = Math.max(2 * gap, grow + next + toward + gap);
    }
}
function stepRows(words, at, height, preferredRows) {
    var spans = units(words), rows = [], seed = at / 1000, k = 0;
    var count = Math.min(spans.length, Math.max(1, Math.floor(height * .65 / 100), preferredRows||0));
    var left = spans.length, unit = 0;
    for (var i = 0; i < count; ++i) {
        var n = left;
        if (i < count - 1) {
            var avg = left / (count - i);
            n = Math.min(Math.ceil(avg * 1.5), Math.max(1, Math.round(avg + (random(seed, ++k) - .5) * avg)));
            // Long mixed-script lines need balanced groups to prevent one wide
            // row from shrinking every other row to an unreadable size.
            if(preferredRows>1)n=Math.min(n,Math.ceil(avg));
        }
        n = Math.max(1, Math.min(n, left - (count - i - 1)));
        var stagger = 20 + random(seed, ++k) * 80;
        rows.push({from:spans[unit][0], to:spans[unit+n-1][1], x:i%2===0?-stagger:stagger,
                   y:(i-(count-1)/2)*2.5, scale:.8+random(seed,++k)*.9, left:i%2===0});
        unit += n; left -= n;
    }
    return rows;
}
function split(words, spans, count) {
    var total = length(words), before = [0], parts = [], from = 0;
    spans.forEach(function(u) { before.push(before[before.length-1] + length(words.slice(u[0],u[1]))); });
    for (var k = 1; k < count; ++k) {
        var at = -1, best = 0;
        for (var cut = from + 1; cut <= spans.length - (count-k); ++cut) {
            var d = Math.abs(before[cut] - total*k/count);
            var text = chars(words[spans[cut-1][1]-1].text.trim());
            if (mark(text[text.length-1]||"")) d -= total*.15;
            if (at < 0 || d < best) { at=cut; best=d; }
        }
        parts.push({from:spans[from][0],to:spans[at-1][1],lean:false,tail:false}); from=at;
    }
    if (spans.length) parts.push({from:spans[from][0],to:spans[spans.length-1][1],lean:false,tail:false});
    return parts;
}
function tiltParts(words, at, fits) {
    var spans=units(words), seed=at/1000, count=4, parts=[];
    var score=Math.log(length(words)+4)/Math.log(24)*(random(seed,1)*.6+.7)*.75;
    var thresholds=[.45,1.05,1.7];
    for(var i=0;i<thresholds.length;++i) if(score<thresholds[i]) {count=i+1;break;}
    for(;;) {
        parts=split(words,spans,Math.min(count,spans.length));
        var lean=[];
        parts.forEach(function(p,i){if(random(seed,100+i)<.35)lean.push(i);});
        if(lean.length)parts[lean[Math.floor(random(seed,200)*lean.length)]].lean=true;
        if(count>=4||count>=spans.length||fits(parts))break;
        ++count;
    }
    var n=parts.length;
    if(n>1&&!parts[n-1].lean) {var last=length(words.slice(parts[n-1].from,parts[n-1].to));parts[n-1].tail=last<=2&&last*2<=length(words.slice(parts[n-2].from,parts[n-2].to));}
    return parts;
}
function wordState(word, shape, position) {
    var start=word.startMs-80, end=Math.max(word.endMs,word.startMs+150);
    var since=(position-start)/1000, after=(position-end)/1000, singing=Math.max(.08,(end-word.startMs)/1000);
    var x=shape.x+Math.sin(shape.y)*100, y=shape.y+Math.cos(shape.x)*50;
    var scale=.5, rotate=shape.rotate+20, opacity=0, blur=10, ink=.5, glow=0;
    if(since>0) {
        var e=spring(since);x=mix(x,shape.x,e);y=mix(y,shape.y,e);scale=mix(.5,shape.scale*1.4,e);
        rotate=mix(shape.rotate+20,shape.rotate,e);opacity=clamp(since/.1);blur=10*(1-clamp(since/.2));
        ink=mix(.5,1,clamp(since/singing));glow=clamp(since/Math.max(.08,.3*singing));
    }
    if(after>0) {
        var q=cubic(after/.5);scale=mix(shape.scale*1.4,shape.scale,q);opacity=mix(1,.82,q);
        rotate=shape.rotate+shape.drift*clamp(after/5);ink=mix(1,.5,cubic(after/.8));glow=1-clamp(after/.9);
    }
    return {x:x,y:y,scale:scale,rotate:rotate,opacity:opacity,blur:blur,ink:ink,glow:glow};
}

// Measure only on layout changes; playback frames evaluate wordState, never reflow.
function layout(line, style, width, height, measure) {
    var words=line.words&&line.words.length?line.words:[{text:line.text||"",startMs:line.startMs||0,endMs:line.endMs||0}];
    if(!line.text||width<=0||height<=0)return [];
    var at=Number(line.startMs||0), f=Math.min(64,Math.max(36,width*.045))*(style==="tilt"?1.125:1), result=[];
    function measured(text,size,lean){return measure(text,lean)*size/64;}
    function appendRow(from,to,size,rowShape,centerY,styleName,partIndex) {
        var shapes=[], widths=[], sum=0;
        for(var i=from;i<to;++i) {
            var ws=styleName==="steps"?words[from].startMs/1000+(i-from)*7.13:at+i;
            var shape={x:(random(ws,1)-.5)*(styleName==="steps"?12:36), y:(random(ws,2)-.5)*(styleName==="steps"?12:36),
                       rotate:(random(ws,3)-.5)*(styleName==="steps"?6:10),scale:styleName==="steps"?rowShape.scale:1.1+random(ws,4)*.2,
                       drift:(random(ws,styleName==="steps"?8:5)-.5)*(styleName==="steps"?20:10)};
            shapes.push(shape);widths.push(measured(words[i].text,size,false));
        }
        space(shapes,widths,size*(styleName==="steps"?.1:.08));
        if(styleName==="steps"&&shapes.length)shapes[shapes.length-1].margin=0;
        for(var k=0;k<shapes.length;++k)sum+=widths[k]+(k+1<shapes.length?shapes[k].margin:0);
        var fit=styleName==="steps"?1:Math.min(1,(width*.8)/Math.max(1,sum));size*=fit;
        var x=(width-sum*fit)/2;
        for(var n=0;n<shapes.length;++n) {
            var s=shapes[n];s.last=from+n===words.length-1;
            result.push({word:words[from+n],shape:s,x:x,y:centerY-size*.7,width:widths[n]*fit,size:size,
                         row:rowShape,part:partIndex,kind:styleName,first:words[from].startMs});
            x+=(widths[n]+s.margin)*fit;
        }
    }
    if(style==="steps") {
        if(length(words)>40)f*=.8;f*=.8;
        var naturalWidth=words.reduce(function(n,w){return n+measured(w.text,f,false)*1.8+f*.2;},0);
        var rows=stepRows(words,at,height,Math.ceil(naturalWidth/Math.max(1,width*.8))), total=0;
        rows.forEach(function(row,i){
            var pad=Math.max(0,f*(row.scale*1.4-1)/2);
            row.height=f*1.5+6+pad*2+10;row.top=total;total+=row.height;
            appendRow(row.from,row.to,f,row,row.top+pad+3+f*.7,"steps",i);
        });
        var extent=0;
        rows.forEach(function(row){
            var cells=result.filter(function(w){return w.row===row;});
            row.first=words[row.from].startMs;row.end=words[row.to-1].endMs;
            row.leftEdge=cells[0].x-8;row.rightEdge=cells[cells.length-1].x+cells[cells.length-1].width+8;
            row.center=(row.leftEdge+row.rightEdge)/2;row.bottom=row.top+row.height-10;
            // space() already reserves the expanded glyphs between words. Only
            // the outer glyphs need extra padding; scaling the entire row again
            // double-counts expansion and makes long lyrics unnecessarily tiny.
            extent=Math.max(extent,row.rightEdge-row.leftEdge+Math.max(0,f*(row.scale*1.4-1))+2*Math.abs(row.x)+80);
        });
        // Preserve the source row proportions; fit the whole composition, never
        // shrink individual rows independently or pack them into a fixed gap.
        var fit=Math.min(1,width*.9/Math.max(1,extent),height*.86/Math.max(1,total));
        result.forEach(function(w){w.x=width/2+(w.x-width/2)*fit;w.y=(height-total*fit)/2+w.y*fit+w.row.y*fit;w.size*=fit;w.width*=fit;});
        rows.forEach(function(row){row.x*=fit;row.center=width/2+(row.center-width/2)*fit;row.leftEdge=width/2+(row.leftEdge-width/2)*fit;row.rightEdge=width/2+(row.rightEdge-width/2)*fit;row.bottom=(height-total*fit)/2+(row.bottom+row.y)*fit;});
    } else if(style==="tilt") {
        function partWidth(p){return measured(words.slice(p.from,p.to).map(function(w){return w.text;}).join("").trim(),f,p.lean)+length(words.slice(p.from,p.to))*f*(p.lean?.15:.08);}
        var parts=tiltParts(words,at,function(parts){return parts.every(function(p){return partWidth(p)<=width*.85;});});
        var widest=parts.reduce(function(n,p){return Math.max(n,partWidth(p));},0);
        if(widest>width*.85)f*=Math.max(.5,width*.85/widest);
        var rowHeight=Math.min(f*1.65+14,height*.8/Math.max(1,parts.length));
        parts.forEach(function(p,pi){
            var size=f*(p.tail?1.18:1), glyphs=[], k=0, total=0;
            for(var wi=p.from;wi<p.to;++wi) {
                var word=words[wi], text=word.text.replace(/\s+$/,""), letters=chars(text), each=(word.endMs-word.startMs)/Math.max(1,letters.length);
                letters.forEach(function(ch,i){
                    if(/\s/.test(ch)){total+=size*(p.lean?.35:.25);return;}
                    var w=measured(ch,size,p.lean);
                    glyphs.push({word:{text:ch,startMs:word.startMs+i*each,endMs:word.startMs+(i+1)*each},shape:{last:wi===words.length-1&&i===0},
                                 x:total,y:height*.46+(pi-(parts.length-1)/2)*rowHeight-size*.7,width:w,size:size,row:p,part:pi,kind:"tilt",first:words[p.from].startMs,order:k++});
                    total+=w+size*(p.lean?.15:.08);
                });
                if(text!==word.text&&wi<p.to-1)total+=size*(p.lean?.35:.25);
            }
            glyphs.forEach(function(g){g.x+=(width-total)/2;result.push(g);});
        });
    } else {
        // The source wraps at word boundaries; retain its deterministic alignment and lift.
        var shapes=[], widths=[];
        words.forEach(function(w,i){var ws=at+i;shapes.push({x:(random(ws,1)-.5)*36,y:(random(ws,2)-.5)*36,rotate:(random(ws,3)-.5)*10,scale:1.1+random(ws,4)*.2,drift:(random(ws,5)-.5)*10,last:i===words.length-1});widths.push(measured(w.text,f,false));});
        space(shapes,widths,f*.08);
        var rows=[[]], used=0;
        words.forEach(function(w,i){var w0=widths[i]+shapes[i].margin;if(used+w0>width*.8&&rows[rows.length-1].length){rows.push([]);used=0;}rows[rows.length-1].push(i);used+=w0;});
        var lift=[-.14,0,.12][Math.floor(at*2)%3]*height;
        // Reserve the expanded glyph and its vertical motion before fitting the
        // whole composition. Compressing row spacing alone makes long lines overlap.
        var rowH=f*1.8+18, compositionFit=Math.min(1,height*.86/(rowH*rows.length));
        var liftLimit=Math.max(0,(height-rowH*rows.length*compositionFit)/2-8);
        lift=Math.max(-liftLimit,Math.min(liftLimit,lift));
        rows.forEach(function(row,ri){
            var sum=row.reduce(function(n,i){return n+widths[i]+(i===row[row.length-1]?0:shapes[i].margin);},0);
            var fit=Math.min(1,width*.8/Math.max(1,sum)), align=Math.floor(at)%3;
            var x=width*.1+(width*.8-sum*fit)*(align===0?0:align===1?.5:1);
            row.forEach(function(i){
                var shape=shapes[i];shape.x*=compositionFit;shape.y*=compositionFit;
                result.push({word:words[i],shape:shape,x:width/2+(x-width/2)*compositionFit,
                    y:height*.5+lift+((ri-(rows.length-1)/2)*rowH-f*.7)*compositionFit,
                    width:widths[i]*fit*compositionFit,size:f*fit*compositionFit,kind:"flow"});
                x+=(widths[i]+shape.margin)*fit;
            });
        });
    }
    return result;
}
