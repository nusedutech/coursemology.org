//Constants
var DATA_HOVER_KEY = "data-hover-status";
var DATA_HIDE_STATUS = "hide";
var DATA_SHOW_STATUS = "show";
var G_NODE_KEY = "g-node-key-";
var G_EDGELABEL_REQUIRED_KEY = "g-edgelabel-required-key-";
var G_EDGELABEL_DEPENDENT_KEY = "g-edgelabel-dependent-key-";
var G_EDGEPATH_REQUIRED_KEY = "g-edgepath-required-key-";
var G_EDGEPATH_DEPENDENT_KEY = "g-edgepath-dependent-key-";

var NODE_ENTRY_CLASS = "node enter entry";
var NODE_FAILED_CLASS = "node enter failed";
var NODE_ENTRY_CURRENT_CLASS = "node enter entryin";
var NODE_ENABLED_CLASS = "node enter enabled";
var NODE_DISABLED_CLASS = "node enter disabled";
var EDGE_ENTRY_START_CLASS = "entrystart";
var EDGE_ENABLED_START_CLASS = "enabledstart";
var EDGE_DISABLED_START_CLASS = "disabledstart";
var EDGE_ENTRY_END_CLASS = "entryend";
var EDGE_ENABLED_END_CLASS = "enabledend";
var EDGE_DISABLED_END_CLASS = "disabledend";
var EDGE_PASSED_CLASS = "passed";
var EDGE_DISABLED_CLASS = "disabled";

var student_attempt_pie_json = 
	{
		"header": {
			"title": {
				"text": "Concept based - student attempts",
				"fontSize": 24,
				"font": "open sans"
			},
			"subtitle": {
				"text": "Size Comparison for student attempts (For current attempting submissions only)",
				"color": "#999999",
				"fontSize": 12,
				"font": "open sans"
			},
			"titleSubtitlePadding": 9
		},
		"footer": {
			"color": "#999999",
			"fontSize": 10,
			"font": "open sans",
			"location": "bottom-left"
		},
		"size": {
			"canvasWidth": 590,
			"pieInnerRadius": "50%",
			"pieOuterRadius": "90%"
		},
		"data": {
			"sortOrder": "value-desc",
			"content": []
		},
		"labels": {
			"outer": {
				"pieDistance": 32
			},
			"inner": {
				"hideWhenLessThanPercentage": 3
			},
			"mainLabel": {
				"fontSize": 11
			},
			"percentage": {
				"color": "#ffffff",
				"decimalPlaces": 0
			},
			"value": {
				"color": "#adadad",
				"fontSize": 11
			},
			"lines": {
				"enabled": true
			}
		},
		"tooltips": {
			"enabled": true,
			"type": "caption",
			"styles": {
				"backgroundColor": "#0055CC",
				"backgroundOpacity": 0.9,
				"color": "#FFFFFF",
				"borderRadius": 4,
				"font": "verdana",
				"fontSize": 14,
				"padding": 10
			}
		},
		"effects": {
			"pullOutSegmentOnClick": {
				"effect": "linear",
				"speed": 400,
				"size": 8
			}
		},
		"misc": {
			"gradient": {
				"enabled": true,
				"percentage": 100
			}
		}
	};

function set_student_attempt_pie_json_areas(attempted) {

	var index = 0;
	while (attempted.length > 0) {
		var curr = attempted.shift();
		var currResponse =  {
								"label": curr.title,
								"value": curr.value,
								"caption": ""
				    		};

		if (curr.students.length > 0) {
			currResponse.caption += "Attempted: "
			while (curr.students.length > 1) {
				currResponse.caption += curr.students[0].name+", ";
				curr.students.shift();
			}

			currResponse.caption += curr.students[0].name;
		}

		student_attempt_pie_json.data.content.push(currResponse);
		index++;
	}

}


function setup_node_edges_color(nodelist) {
    $.each(nodelist, function(){	
	    if (this.enabled && this.is_entry) { 
			  $("#"+G_NODE_KEY+this.concept_id).attr("class", NODE_ENTRY_CLASS);
        $("."+G_EDGEPATH_REQUIRED_KEY+this.concept_id).each(function(){
          add_class(this, EDGE_ENTRY_START_CLASS);
        });
        $("."+G_EDGEPATH_DEPENDENT_KEY+this.concept_id).each(function(){
          add_class(this, EDGE_ENTRY_END_CLASS);
        });
        $("."+G_EDGELABEL_REQUIRED_KEY+this.concept_id).each(function(){
          add_class(this, EDGE_ENTRY_START_CLASS);
        });
        $("."+G_EDGELABEL_DEPENDENT_KEY+this.concept_id).each(function(){
          add_class(this, EDGE_ENTRY_END_CLASS);
        });
	    }
	    else if (this.enabled) {
	      $("#"+G_NODE_KEY+this.concept_id).attr("class", NODE_ENABLED_CLASS);
        $("."+G_EDGEPATH_REQUIRED_KEY+this.concept_id).each(function(){
          add_class(this, EDGE_ENABLED_START_CLASS);
        });
        $("."+G_EDGEPATH_DEPENDENT_KEY+this.concept_id).each(function(){
          add_class(this, EDGE_ENABLED_END_CLASS);
        });
        $("."+G_EDGELABEL_REQUIRED_KEY+this.concept_id).each(function(){
          add_class(this, EDGE_ENABLED_START_CLASS);
        });
        $("."+G_EDGELABEL_DEPENDENT_KEY+this.concept_id).each(function(){
          add_class(this, EDGE_ENABLED_END_CLASS);
        });
	    }
	    else {
	      $("#"+G_NODE_KEY+this.concept_id).attr("class", NODE_DISABLED_CLASS);
        $("."+G_EDGEPATH_REQUIRED_KEY+this.concept_id).each(function(){
          add_class(this, EDGE_DISABLED_START_CLASS);
        });
        $("."+G_EDGEPATH_DEPENDENT_KEY+this.concept_id).each(function(){
          add_class(this, EDGE_DISABLED_END_CLASS);
        });
        $("."+G_EDGELABEL_REQUIRED_KEY+this.concept_id).each(function(){
          add_class(this, EDGE_DISABLED_START_CLASS);
        });
        $("."+G_EDGELABEL_DEPENDENT_KEY+this.concept_id).each(function(){
          add_class(this, EDGE_DISABLED_END_CLASS);
        });
	    }     
	  });
  }

  function setup_node_edges_color_under_submission(nodelist) {
    $.each(nodelist, function(){  
      if (this.enabled) {
        $("#"+G_NODE_KEY+this.concept_id).attr("class", NODE_ENABLED_CLASS);
        $("."+G_EDGEPATH_REQUIRED_KEY+this.concept_id).each(function(){
          add_class(this, EDGE_ENABLED_START_CLASS);
        });
        $("."+G_EDGEPATH_DEPENDENT_KEY+this.concept_id).each(function(){
          add_class(this, EDGE_ENABLED_END_CLASS);
        });
        $("."+G_EDGELABEL_REQUIRED_KEY+this.concept_id).each(function(){
          add_class(this, EDGE_ENABLED_START_CLASS);
        });
        $("."+G_EDGELABEL_DEPENDENT_KEY+this.concept_id).each(function(){
          add_class(this, EDGE_ENABLED_END_CLASS);
        });
      }
      else {
        $("#"+G_NODE_KEY+this.concept_id).attr("class", NODE_DISABLED_CLASS);
        $("."+G_EDGEPATH_REQUIRED_KEY+this.concept_id).each(function(){
          add_class(this, EDGE_DISABLED_START_CLASS);
        });
        $("."+G_EDGEPATH_DEPENDENT_KEY+this.concept_id).each(function(){
          add_class(this, EDGE_DISABLED_END_CLASS);
        });
        $("."+G_EDGELABEL_REQUIRED_KEY+this.concept_id).each(function(){
          add_class(this, EDGE_DISABLED_START_CLASS);
        });
        $("."+G_EDGELABEL_DEPENDENT_KEY+this.concept_id).each(function(){
          add_class(this, EDGE_DISABLED_END_CLASS);
        });
      }     
    });
  }

  function setup_current_node_edges_color(lastAtmNode) {
    if (lastAtmNode != null) {
      $("#"+G_NODE_KEY+lastAtmNode.id).attr("class", NODE_ENTRY_CURRENT_CLASS);
      $("."+G_EDGEPATH_REQUIRED_KEY+lastAtmNode.id).each(function(){
        add_class(this, EDGE_ENTRY_START_CLASS);
      });
      $("."+G_EDGEPATH_DEPENDENT_KEY+lastAtmNode.id).each(function(){
        add_class(this, EDGE_ENTRY_END_CLASS);
      });
      $("."+G_EDGELABEL_REQUIRED_KEY+lastAtmNode.id).each(function(){
        add_class(this, EDGE_ENTRY_START_CLASS);
      });
      $("."+G_EDGELABEL_DEPENDENT_KEY+lastAtmNode.id).each(function(){
        add_class(this, EDGE_ENTRY_END_CLASS);
      });
    }
  }

  function setup_passed_nodes_edges_color(openAtmNodes) {
    if (openAtmNodes != null) {
      $.each(openAtmNodes, function(){  
        $("#"+G_NODE_KEY+this.id).attr("class", NODE_ENTRY_CLASS);
        $("."+G_EDGEPATH_REQUIRED_KEY+this.id).each(function(){
          add_class(this, EDGE_ENTRY_START_CLASS);
        });
        $("."+G_EDGEPATH_DEPENDENT_KEY+this.id).each(function(){
          add_class(this, EDGE_ENTRY_END_CLASS);
        });
        $("."+G_EDGELABEL_REQUIRED_KEY+this.id).each(function(){
          add_class(this, EDGE_ENTRY_START_CLASS);
        });
        $("."+G_EDGELABEL_DEPENDENT_KEY+this.id).each(function(){
          add_class(this, EDGE_ENTRY_END_CLASS);
        });
      }); 
    }
  }

  function setup_passed_edges_color(openAtmEdges) {
    if (openAtmEdges != null) {
      $.each(openAtmEdges, function(){  
        $("."+G_EDGEPATH_REQUIRED_KEY+this.required_id).each(function(){
          add_class(this, EDGE_PASSED_CLASS);
          remove_class(this, EDGE_ENABLED_START_CLASS);
          remove_class(this, EDGE_ENABLED_END_CLASS);
          remove_class(this, EDGE_ENTRY_START_CLASS);
          remove_class(this, EDGE_ENTRY_END_CLASS);
          remove_class(this, EDGE_DISABLED_START_CLASS);
          remove_class(this, EDGE_DISABLED_END_CLASS);
        });
        $("."+G_EDGELABEL_REQUIRED_KEY+this.required_id).each(function(){
          add_class(this, EDGE_PASSED_CLASS);
          remove_class(this, EDGE_ENABLED_START_CLASS);
          remove_class(this, EDGE_ENABLED_END_CLASS);
          remove_class(this, EDGE_ENTRY_START_CLASS);
          remove_class(this, EDGE_ENTRY_END_CLASS);
          remove_class(this, EDGE_DISABLED_START_CLASS);
          remove_class(this, EDGE_DISABLED_END_CLASS);
        });
      }); 
    }
  }

  function setup_failed_nodes_edges_color(failedNodes) {
    if (failedNodes != null) {
      $.each(failedNodes, function(){  
        $("#"+G_NODE_KEY+this.id).attr("class", NODE_FAILED_CLASS);
        $("."+G_EDGEPATH_REQUIRED_KEY+this.id).each(function(){
          add_class(this, EDGE_ENABLED_START_CLASS);
        });
        $("."+G_EDGEPATH_DEPENDENT_KEY+this.id).each(function(){
          add_class(this, EDGE_ENABLED_END_CLASS);
        });
        $("."+G_EDGELABEL_REQUIRED_KEY+this.id).each(function(){
          add_class(this, EDGE_ENABLED_START_CLASS);
        });
        $("."+G_EDGELABEL_DEPENDENT_KEY+this.id).each(function(){
          add_class(this, EDGE_ENABLED_END_CLASS);
        });
      }); 
    }
  }

  function setup_disabled_edges_color(edgelist) {
    $.each(edgelist, function(){ 
      if (!this.enabled) { 
        $("."+G_EDGEPATH_REQUIRED_KEY+this.required_id).each(function(){
          add_class(this, EDGE_DISABLED_CLASS);
          remove_class(this, EDGE_ENABLED_START_CLASS);
          remove_class(this, EDGE_ENABLED_END_CLASS);
          remove_class(this, EDGE_ENTRY_START_CLASS);
          remove_class(this, EDGE_ENTRY_END_CLASS);
          remove_class(this, EDGE_DISABLED_START_CLASS);
          remove_class(this, EDGE_DISABLED_END_CLASS);
        });
        $("."+G_EDGELABEL_REQUIRED_KEY+this.required_id).each(function(){
          add_class(this, EDGE_DISABLED_CLASS);
          remove_class(this, EDGE_ENABLED_START_CLASS);
          remove_class(this, EDGE_ENABLED_END_CLASS);
          remove_class(this, EDGE_ENTRY_START_CLASS);
          remove_class(this, EDGE_ENTRY_END_CLASS);
          remove_class(this, EDGE_DISABLED_START_CLASS);
          remove_class(this, EDGE_DISABLED_END_CLASS);
        });
      }
    });
  }

  function setup_edgepaths_arrow_heads() {
    $("g.edgePath."+EDGE_ENTRY_START_CLASS+"."+EDGE_ENTRY_END_CLASS+" path, " +
      "g.edgePath."+EDGE_PASSED_CLASS+" path").each(function(){
      $(this).attr("marker-end", "url(#arrowGreen)");
    });

    $("g.edgePath."+EDGE_ENTRY_START_CLASS+"."+EDGE_DISABLED_END_CLASS+" path, " +
      "g.edgePath."+EDGE_ENTRY_START_CLASS+"."+EDGE_ENABLED_END_CLASS+" path").each(function(){
      $(this).attr("marker-end", "url(#arrowYellow)");
    });

    $("g.edgePath."+EDGE_ENABLED_START_CLASS+"."+EDGE_ENABLED_END_CLASS+" path, " +
      "g.edgePath."+EDGE_ENABLED_START_CLASS+"."+EDGE_DISABLED_END_CLASS+" path, " +
      "g.edgePath."+EDGE_ENABLED_START_CLASS+"."+EDGE_ENTRY_END_CLASS+" path").each(function(){
      $(this).attr("marker-end", "url(#arrowBlack)");
    });

    $("g.edgePath."+EDGE_DISABLED_START_CLASS+"."+EDGE_ENTRY_END_CLASS+" path, " +
      "g.edgePath."+EDGE_DISABLED_START_CLASS+"."+EDGE_ENABLED_END_CLASS+" path, " +
      "g.edgePath."+EDGE_DISABLED_START_CLASS+"."+EDGE_DISABLED_END_CLASS+" path").each(function(){
      $(this).attr("marker-end", "url(#arrowBlack)");
    });
  }

  function get_length(obj) {
    var count = 0;
    for (something in obj) {
      ++count;
    }
    return count;
  }

  //Only for use on svg related elements
  function remove_class (obj, name) {
    var classesStr = $(obj).attr("class");
    var classes = classesStr.split(" ");
    for (var i = 0; i < classes.length ; i++ ) {
      if (classes[i] == name) {
        classes.splice(i,1);
        $(obj).attr("class", classes.join(" "));
        return true;
      }
    }
    return false;
  }

  //Only for use on svg related elements
  function add_class (obj, name) {
    var classesStr = $(obj).attr("class");
    var classes = classesStr.split(" ");
    for (var i = 0; i < classes.length ; i++ ) {
      if (classes[i] == name) {
        return false;
      }
    }
    classes.push(name);
    $(obj).attr("class", classes.join(" "));
    return true;
  }

  //Only for use on svg related elements
  function has_class (obj, name) {
    var classesStr = $(obj).attr("class");
    var classes = classesStr.split(" ");
    for (var i = 0; i < classes.length ; i++ ) {
      if (classes[i] == name) {
        return true;
      }
    }
    return false;
  }