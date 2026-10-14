/* Built-in manual search. As you type, the main area becomes a results page,
 * grouped by part of the manual and updated live. Works in the multi-page
 * site (loads search-index.json next to this file) and in the single-page
 * manual (indexes its own sections). No third-party service. */
(function () {
	'use strict';
	var form = document.getElementById('rc-search');
	var content = document.getElementById('content');
	if (!form || !content) return;
	var input = document.getElementById('rc-search-input');
	var status = document.getElementById('rc-search-status');
	var onePage = document.body.hasAttribute('data-search-onepage');
	var script = document.currentScript;
	var base = script && script.src ? script.src.replace(/[^\/]*$/, '') : '';
	var PER_GROUP = 6;
	var docs = null, loading = false, timer = null;

	var panel = document.createElement('section');
	panel.id = 'rc-results';
	panel.setAttribute('aria-label', 'Search results');
	panel.hidden = true;
	content.insertBefore(panel, content.firstChild);

	function esc(s) {
		return s.replace(/[&<>"]/g, function (c) {
			return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c];
		});
	}
	function reEsc(s) { return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); }

	// Very light stemming so "distribute" finds "distributing", "takes" finds "take".
	function stem(t) {
		if (t.length > 5) t = t.replace(/(ing|ed)$/, '');
		if (t.length > 4) t = t.replace(/(es|s|e)$/, '');
		return t;
	}

	function prepare(list_) {
		list_.forEach(function (d) {
			d.lt = (d.t + ' ' + (d.h || '')).toLowerCase();
			d.lx = d.x.toLowerCase();
		});
		return list_;
	}

	function fromDom() {
		var out = [], part = '';
		document.querySelectorAll('.page').forEach(function (p) {
			if (p.id === 'page-toc') return;
			var id = p.id.replace(/^page-/, '');
			var first = p.querySelector('h1, h2, h3, h4, h5, h6');
			var title = first ? first.textContent.trim() : id;
			if (p.querySelector('#subtopics')) { part = title; return; } // a Part page
			var cur = { t: title, p: part, u: '#' + id, h: '', a: '', x: '' };
			var secs = [cur];
			Array.prototype.forEach.call(p.children, function (c) {
				if (/^H[1-6]$/.test(c.tagName)) {
					if (c === first) return;
					var h = c.textContent.trim();
					cur = { t: title, p: part, u: '#' + id, h: h, a: c.id || '', x: h };
					secs.push(cur);
				} else {
					cur.x += ' ' + c.textContent;
				}
			});
			secs.forEach(function (s) {
				s.x = s.x.replace(/\s+/g, ' ').trim();
				if (s.x) out.push(s);
			});
		});
		return out;
	}

	function load(cb) {
		if (docs) return cb();
		if (onePage) { docs = prepare(fromDom()); return cb(); }
		if (loading) return;
		loading = true;
		fetch(base + 'search-index.json').then(function (r) {
			if (!r.ok) throw new Error(r.status);
			return r.json();
		}).then(function (j) {
			docs = prepare(j); loading = false; cb();
		}).catch(function () {
			loading = false;
			showMessage('Search is not available right now.');
		});
	}

	function snippet(d, tokens, phrase) {
		// Sections are indexed as "<heading> <body>"; the heading is already the result
		// title, so build the snippet from the body when it has a match.
		var off = d.h && d.x.indexOf(d.h) === 0 ? d.h.length + 1 : 0;
		var pos = tokens.length > 1 ? d.lx.indexOf(phrase, off) : -1;
		if (pos < 0) {
			var best = -1;
			for (var i = 0; i < tokens.length; i++) {
				var count = 0, from = off, k, first = -1;
				while ((k = d.lx.indexOf(tokens[i], from)) >= 0 && count < 60) {
					if (first < 0) first = k;
					count++; from = k + tokens[i].length;
				}
				if (first >= 0 && (best < 0 || count < best)) { best = count; pos = first; }
			}
		}
		if (pos < 0) pos = off;
		var start = Math.max(off, pos - 70);
		var end = Math.min(d.x.length, pos + 160);
		var chunk = d.x.slice(start, end);
		if (start > off) { var sp = chunk.indexOf(' '); if (sp >= 0 && sp < 25) chunk = chunk.slice(sp + 1); }
		if (end < d.x.length) { var lp = chunk.lastIndexOf(' '); if (lp > chunk.length - 25) chunk = chunk.slice(0, lp); }
		var s = (start > off ? '\u2026 ' : '') + chunk + (end < d.x.length ? ' \u2026' : '');
		return highlight(s, tokens);
	}

	function highlight(text, tokens) {
		var re = new RegExp('(\\w*(?:' + tokens.map(function (t) { return reEsc(esc(t)); }).join('|') + ')\\w*)', 'gi');
		return esc(text).replace(re, '<mark>$1</mark>');
	}

	function score(d, tokens, phrase) {
		var s = 0;
		for (var i = 0; i < tokens.length; i++) {
			var t = tokens[i];
			var inTitle = d.lt.indexOf(t) >= 0;
			var count = 0, from = 0, k;
			while ((k = d.lx.indexOf(t, from)) >= 0 && count < 10) { count++; from = k + t.length; }
			if (!inTitle && count === 0) return 0;
			s += (inTitle ? 20 : 0) + count;
		}
		if (tokens.length > 1 && (d.lt.indexOf(phrase) >= 0 || d.lx.indexOf(phrase) >= 0)) s += 30;
		return s;
	}

	function link(d) {
		var href = onePage ? d.u : base + d.u + (d.a ? '#' + d.a : '');
		return '<a class="rc-title" href="' + esc(href) + '"' +
			(onePage ? ' data-page="' + esc(d.u.slice(1)) + '" data-anchor="' + esc(d.a || '') + '"' : '') + '>' +
			highlight(d.h || d.t, currentTokens) + '</a>';
	}

	var currentTokens = [];

	function render(q) {
		var raw = q.toLowerCase().split(/\s+/).filter(Boolean);
		var tokens = raw.map(stem).filter(Boolean);
		var phrase = raw.join(' ');
		currentTokens = tokens;
		var groups = [], byPart = {};
		var total = 0;
		docs.forEach(function (d) {
			var s = score(d, tokens, phrase);
			if (!s) return;
			var name = d.p || 'Manual';
			if (!byPart[name]) { byPart[name] = { name: name, hits: [] }; groups.push(byPart[name]); }
			byPart[name].hits.push({ d: d, s: s });
			total++;
		});
		var shownQuery = esc(q.trim());
		if (!total) {
			panel.innerHTML = '<h2 class="rc-heading">No results for “' + shownQuery + '”</h2>' +
				'<p class="rc-hint">Check the spelling, or try fewer or different words.</p>';
			status.textContent = 'No results.';
			return;
		}
		var html = '<h2 class="rc-heading">' + total + ' result' + (total === 1 ? '' : 's') + ' for “' + shownQuery + '”</h2>';
		groups.forEach(function (g) {
			g.hits.sort(function (a, b) { return b.s - a.s; });
			g.best = g.hits[0].s;
		});
		groups.sort(function (a, b) { return b.best - a.best; });
		groups.forEach(function (g, gi) {
			html += '<section class="rc-group" aria-labelledby="rc-g' + gi + '">' +
				'<h3 id="rc-g' + gi + '">' + esc(g.name) + '<span class="rc-count">' + g.hits.length + ' result' + (g.hits.length === 1 ? '' : 's') + '</span></h3><ol>';
			g.hits.forEach(function (h, i) {
				var d = h.d;
				var crumb = d.h ? esc(d.p ? d.p + ' › ' + d.t : d.t) : esc(d.p || '');
				html += '<li class="rc-result' + (i >= PER_GROUP ? ' rc-extra' : '') + '">' + link(d) +
					(crumb ? '<div class="rc-crumb">' + crumb + '</div>' : '') +
					'<p class="rc-snippet">' + snippet(d, tokens, phrase) + '</p></li>';
			});
			html += '</ol>';
			if (g.hits.length > PER_GROUP) {
				html += '<button type="button" class="rc-more" aria-expanded="false">Show ' + (g.hits.length - PER_GROUP) +
					' more in ' + esc(g.name) + '</button>';
			}
			html += '</section>';
		});
		panel.innerHTML = html;
		status.textContent = total + ' result' + (total === 1 ? '' : 's') + '. Press Down arrow to move to the results.';
	}

	function showMessage(msg) {
		panel.innerHTML = '<p class="rc-hint">' + esc(msg) + '</p>';
		show();
		status.textContent = msg;
	}

	function show() {
		var wasHidden = panel.hidden;
		panel.hidden = false;
		content.classList.add('rc-searching');
		// Opening the results from a page that was scrolled to a heading must
		// show the top of the results, not wherever the page happened to be.
		if (wasHidden) window.scrollTo(0, 0);
	}

	function clear() {
		panel.hidden = true;
		panel.innerHTML = '';
		content.classList.remove('rc-searching');
		status.textContent = '';
	}

	function run() {
		var q = input.value.trim();
		if (!q) { clear(); return; }
		show();
		if (q.length < 2) {
			panel.innerHTML = '<p class="rc-hint">Keep typing…</p>';
			status.textContent = '';
			return;
		}
		load(function () { render(q); });
	}

	function results() { return Array.prototype.slice.call(panel.querySelectorAll('.rc-result:not(.rc-extra) a.rc-title, .rc-extra.rc-open a.rc-title')); }

	input.addEventListener('input', function () {
		clearTimeout(timer);
		timer = setTimeout(run, 90);
	});
	input.addEventListener('keydown', function (e) {
		if (e.key === 'Escape') { input.value = ''; clear(); }
		else if (e.key === 'ArrowDown') {
			var r = results();
			if (r.length) { e.preventDefault(); r[0].focus(); }
		}
	});
	form.addEventListener('submit', function (e) {
		e.preventDefault();
		clearTimeout(timer);
		run();
		var r = results();
		if (r.length) r[0].click();
	});
	panel.addEventListener('keydown', function (e) {
		var a = document.activeElement;
		if (!a || a.tagName !== 'A') return;
		var r = results(), i = r.indexOf(a);
		if (e.key === 'ArrowDown' && i >= 0 && i < r.length - 1) { e.preventDefault(); r[i + 1].focus(); }
		else if (e.key === 'ArrowUp') { e.preventDefault(); if (i > 0) r[i - 1].focus(); else input.focus(); }
		else if (e.key === 'Escape') { input.focus(); }
	});
	panel.addEventListener('click', function (e) {
		var more = e.target.closest('.rc-more');
		if (more) {
			var g = more.parentElement;
			g.querySelectorAll('.rc-extra').forEach(function (li) { li.classList.add('rc-open'); });
			more.parentElement.removeChild(more);
			return;
		}
		if (!onePage) return;
		var a = e.target.closest('a[data-page]');
		if (!a) return;
		e.preventDefault();
		var id = a.getAttribute('data-page');
		input.value = ''; clear();
		if (typeof showPage === 'function') showPage(id);
		history.replaceState(null, null, '#' + id);
		var anchor = a.getAttribute('data-anchor');
		if (anchor) {
			var page = document.getElementById('page-' + id);
			var target = page && page.querySelector('[id="' + anchor.replace(/"/g, '') + '"]');
			if (target) target.scrollIntoView();
		}
	});

	// ?q=term opens straight onto the results (multi-page site).
	if (!onePage) {
		var m = /[?&]q=([^&]*)/.exec(location.search);
		if (m) { try { input.value = decodeURIComponent(m[1].replace(/\+/g, ' ')); run(); } catch (e) { /* ignore */ } }
	}
})();
