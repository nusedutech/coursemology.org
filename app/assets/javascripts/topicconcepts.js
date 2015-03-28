var student_attempt_pie_json = 
	{
		"header": {
			"title": {
				"text": "Concept based - student attempts",
				"fontSize": 24,
				"font": "open sans"
			},
			"subtitle": {
				"text": "Size Comparison for student attempts",
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
