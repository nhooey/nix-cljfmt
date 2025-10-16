(ns cljfmt.wrapper
  (:gen-class)
  (:require [cljfmt.main :as cljfmt]))

(defn -main [& args]
  (apply cljfmt/-main args))
