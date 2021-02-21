EXTENSION_SUFFIX := $(shell python3-config --extension-suffix)

.PHONY: all
all: $(ALL_TARGETS) test
	
contrib/geographiclib/CMakeLists.txt:
	@git submodule update --init

contrib/geographiclib/BUILD/Makefile: contrib/geographiclib/CMakeLists.txt
	@which cmake >/dev/null || (echo "cmake is required to build" && exit 1)
	@mkdir -p contrib/geographiclib/BUILD
	@cd contrib/geographiclib/BUILD && cmake -DCMAKE_INSTALL_PREFIX=../../install -DGEOGRAPHICLIB_LIB_TYPE=STATIC ..

contrib/install/lib/libGeographic.a: contrib/geographiclib/BUILD/Makefile
	@which make >/dev/null || (echo "make is required to build" && exit 1)
	@mkdir -p contrib/install
	@cd contrib/geographiclib/BUILD && make -j 4 install

build/geofun2$(EXTENSION_SUFFIX): packages
	@which c++ >/dev/null || (echo "c++ is required to build" && exit 1)
	@mkdir -p build
	@. venv/bin/activate; c++ -O3 -Wall -shared -std=c++11 -fPIC -I contrib/install/include $(shell python3 -m pybind11 --includes) src/geofun2.cpp -o $@

.PHONY: build
build: contrib/install/lib/libGeographic.a build/geofun2$(EXTENSION_SUFFIX)

.PHONY: install
install: build

.PHONY: test
test: codestyle build
	@echo "Running tests...."
	@. venv/bin/activate; pytest -v tests
	@echo "Done."

test_%: packages
	@. venv/bin/activate; tests/$@.py

.PHONY: codestyle
codestyle: packages
	@. venv/bin/activate; which flake8 >/dev/null || (echo "flake8 checker not available" && exit 1)
	@echo "Checking python code style (PEP8)"
	@. venv/bin/activate; flake8 tests
	@echo "Done."

.PHONY: clean
clean:
	@echo "Cleaning up python cache..."
	@find . -type d -name __pycache__ | xargs rm -rf
	@echo "Cleaning up contrib install..."
	@rm -r contrib/install
	@echo "Cleaning up GeographicLib..."
	@rm -r contrib/geographiclib/BUILD
	@echo "Done."

.PHONY: distclean
distclean: clean
	@echo "Removing virtual environment..."
	@which python | grep venv >/dev/null 2>/dev/null && echo "Deactivate your virtual environment first" && exit 1 || echo "Virtual environment not active" 
	@rm -rf venv
	@echo "Done."

.PHONY: packages
packages: venv/updated

venv/bin/activate:
	@echo "Setting up virtual environment..."
	@(which python3.8 >/dev/null && python3.8 -mvenv venv) || \
	   (which python3.7 >/dev/null && python3.7 -mvenv venv)
	@echo "Done."

venv/updated: venv/bin/activate requirements.txt
	@echo "Installing packages ..." 
	@. venv/bin/activate \
		&& pip install wheel \
		&& pip install ipython \
		&& pip install -r requirements.txt
	@touch venv/updated
	@echo "Done."
