---
title: "Using a JQuery Plugin in Angular 2"
date: 2015-12-04
comments: true
categories: [Angluar]
tags: [test]
keywords: "JQuery, Angular 2, Plugin, Directive"  

---

I have been working on a small content editing tool for an internal project and decided to try using angular 2.  For this project I want to use the TinyMCE.js.  In anglar 1.x I would wrap it in a directive and work with it that way.

<aside class="notice">
This code was testing with alpha 48
</aside>

In angular 2.0 there are no directives, instead we use a component which ends up being much simpler than a directive.  The full code is below folled by a brief explaination.

{{< highlight ts >}}
import {Component, View, ElementRef, OnInit, Input, Output, EventEmitter,OnChanges} from 'angular2/angular2';
declare var tinymce: any;
@Component({
	selector: 'tiny-editor',
})
@View({
	template: `<textarea class="tinyMCE" style="height:300px"></textarea>`
})
export class TinyEditor implements OnInit {

    @Input() value: any;
    @Output() valueChange = new EventEmitter();

    elementRef: ElementRef;
    constructor(elementRef: ElementRef) {
        this.elementRef = elementRef;
    }
    onInit() {
        var that = this;
        tinymce.init(
		{
		  selector: ".tinyMCE",
		  plugins: ["code"],
		  menubar: false,
		  toolbar1: "bold italic underline strikethrough alignleft aligncenter alignright alignjustify styleselect   bullist numlist outdent indent blockquote undo redo removeformat subscript superscript | code",
		  setup: (editor) => {
		  editor.on('change', (e, l) => {
		      that.valueChange.next(editor.getContent());
		  });
		}
	   });
	}
    onChanges(changes){
        if (tinymce.activeEditor)
            tinymce.activeEditor.setContent(this.value);
    }
}
{{< /highlight>}}
With the tinyMCE component we want to have two way binding for the text in the editor.  In order to do this we need to use Input (with OnChanges) and Output (with EventEmmiter).

Usage:
{{< highlight HTML >}}<tiny-editor [value]="model.data" (value-change)="model.data=$event"></tiny-editor>
{{< /highlight>}}
In order to make sure that the editor updates when the text changes we implement the onChanges event which will fire everytime any of the inputs changes.  In this case we only have one input so we can update the editor everytime there is a change.

Updating the model when there is a change in the editor is a little bit more complicated, in order to do this we use an event emmitter. We setup tinyMCE's change event to call 'next' on our event emitter to allow us bind the new data back to the model.


	
