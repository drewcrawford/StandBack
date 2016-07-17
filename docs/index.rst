.. Caroline documentation master file, created by
   sphinx-quickstart on Thu Jun 30 19:41:21 2016.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

StandBack
====================================

.. todolist::

StandBack is a regular expression engine implementing the :code:`egrep` (POSIX-extended) language.  It is cross-platform and has no dependencies.
While :code:`egrep` is a less popular language than PCRE, it is fully capable for basic programming tasks, and our API is *much* easier to use than Foundation's.

.. code-block:: swift

    let r = try! Regex(pattern: "class[[:space:]]+([[:alnum:]]+)[[:space:]]*:CarolineTest[[:space:]]*\\{")
    print(try! r.match("prefix stuff class Foo:CarolineTest {"))



Contents:
====================================

.. toctree::
   :maxdepth: 2

   APIReference



Indices and tables
==================

* :ref:`genindex`
* :ref:`modindex`
* :ref:`search`

