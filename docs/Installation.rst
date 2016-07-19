Installation
=============

To use StandBack, use `Anarchy Tools <http://anarchytools.org>`_.

Add this to your build.atpkg:

.. code-block:: clojure
    
          :external-packages [
            {
              version [">=0.1"]
              :url "https://code.sealedabstract.com/drewcrawford/StandBack.git"
            }
          ]


Make sure to link with :code:`StandBack.a`.