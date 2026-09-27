// This file is compiled by esbuild (see esbuild.config.mjs), along with any other
// files present in this directory. Keep application logic in a relevant structure
// within app/javascript and use this file to reference it.

import "@hotwired/turbo-rails"
require("@rails/activestorage").start()
require("local-time").start()

import './channels/**/*_channel.js'
import "./controllers"

import * as bootstrap from "bootstrap"

document.addEventListener("turbo:load", () => {
  var tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'))
  var tooltipList = tooltipTriggerList.map(function (tooltipTriggerEl) {
    return new bootstrap.Tooltip(tooltipTriggerEl)
  })

  var popoverTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="popover"]'))
  var popoverList = popoverTriggerList.map(function (popoverTriggerEl) {
    return new bootstrap.Popover(popoverTriggerEl)
  })
})
