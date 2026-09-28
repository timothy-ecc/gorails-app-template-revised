// This file is compiled by esbuild (see esbuild.config.mjs), along with any other
// files present in this directory. Keep application logic in a relevant structure
// within app/javascript and use this file to reference them.

import "@hotwired/turbo-rails"
require("@rails/activestorage").start()
require("local-time").start()

import './channels/**/*_channel.js'
import "./controllers"
