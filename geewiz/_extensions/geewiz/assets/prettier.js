window.document.addEventListener("DOMContentLoaded", function (event) {
  console.log('Loading tippy for gcodes')
  function tippyHover(el, contentFn) {
    const config = {
      allowHTML: true,
      content: contentFn,
      maxWidth: 500,
      delay: 100,
      arrow: false,
      appendTo: function(el) {
          return el.parentElement;
      },
      interactive: true,
      interactiveBorder: 10,
      theme: 'quarto',
      placement: 'bottom-start'
    };
    window.tippy(el, config);
  }
  var words = window.document.querySelectorAll('.gcode-word');
  for (var i=0; i<words.length; i++) {
    const word = words[i];
    tippyHover(word, function() {
      let title = word.dataset.gcodeDescription ? word.dataset.gcodeDescription : "This is G-Code or M-Code"
      let comment = word.dataset.gcodeComment ? word.dataset.gcodeComment : "This has no comment"

      title = "<strong>" + title + "</strong><br />"
      comment = "<small>" + comment + "</small>"

      return title + comment;
    });
  }
})