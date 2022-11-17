
import setuptools

setuptools.setup(
    name="postmocot",
    version="0.0.19b0",
    author="Jacob Kravits",
    author_email="kravitsjacob@gmail.com",
    description="Multi-Objective Coordination of Thermoelectric Water Use",
    url="https://github.com/kravitsjacob/water-coordinate",
    project_urls={
        "Bug Tracker": "https://github.com/kravitsjacob/water-coordinate/issues",  # noqa
    },
    install_requires=[
        'pandas',
        'PyYAML',
        'matplotlib',
        'seaborn',
        'hiplot'
    ],
    classifiers=[
        "Programming Language :: Python :: 3",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
    ],
    package_dir={"": "src"},
    packages=setuptools.find_packages(where="src"),
    python_requires=">=3.9",
)
