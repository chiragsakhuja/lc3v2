**Disclaimer:** This document reflects the testing framework as of
release v2.0.0, which is incompatible with prior versions. To see details on the
previous testing framework, which is now deprecated, see [this
document](TEST1.MD).

# Unit tests
Unit tests in this framework are standalone executables that consume LC-3 source
code in binary (`*.bin`) or assembly (`*.asm`), perform a series of tests, and
output a report. In the context of LC3Tools, unit testing will mostly be used by
instructors to automatically grade assignments, but students are encouraged to
use the framework and other advanced debugging features for their own
assignments as well. Unit tests are written in C++ and enable fine control and
insight into LC-3 system as a program is running. Unit tests are also compiled
alongside the command line tools.

This document is geared toward instructors who are writing their first unit
tests in a classroom setting. The bulk of the document is in the form of a
tutorial, and many more details are provided in the [additional
resources](TEST.md#additional-resources) section.

Generally there will be a single unit test for each assignment that consists of
a suite of test cases. The unit test executable consumes a single student's
assignment and outputs a report for that student. In practice, the instructor
will need to write scripts that invokes the unit test for each student and then
aggregates the results. At UT Austin we use Canvas to distribute grades, which
has its own API. This project will soon include a comprehensive script to
interface with Canvas that runs unit tests for every student, aggregates the
results, and uploads the grades to Canvas with the report attached.

Unit test source files live in the `src/test/tests` directory. When a unit test
is built, as per the [build document](BUILD.md), the executable will be
generated in the `build/bin` directory with the same name as the source file for
the unit test (e.g. a unit test labeled `assignment1.cpp` will produce an
executable called `assignment1`).

# Tutorial
This tutorial will cover all the steps necessary to create a unit test for a
simple assignment. This tutorial will assume you are using a *NIX system (macOS
or Linux), although Windows works fine. For a Windows system, adjust the build
commands as described in the [build document](BUILD.md#windows).

**It is recommended that you follow this tutorial from top to bottom to get a
better understanding of how to utilize the testing framework.** We will walk
through a sample assignment.

## Assignment Description
Write an LC-3 assembly program that performs unsigned addition on a set of
numbers in memory and saves the result in location 0x3100. The set of numbers
begins at location 0x3200 and continues until the value 0x0000 is encountered in
a memory location. You may ignore overflow and you may assume there will be no
more than 2048 total numbers to add. Your program must start at location 0x3000.

### Solution
The following assembly program accomplishes the task in the description above:

```
.orig x3000

; intialize registers
;   r0: accumulator
;   r1: address of next value to load
;   r2: temporary space to hold loaded value
        and r0, r0, #0
        ld r1, start

; load value and accumulate until 0 is found
loop    ldr r2, r1, #0
        brz done
        add r0, r0, r2
        add r1, r1, #1
        br loop

; store result and halt
done    sti r0, result
        halt

start   .fill x3200
result  .fill x3100

.end
```

Create this file in the root directory of LC3Tools as `tutorial_sol.asm`.

## Creating a Unit Test
From the root directory, navigate to `src/test/tests/` and create a file
for this unit test called `tutorial_grader.cpp`. Each unit test is expected to
define four functions. For now just define empty functions. As the tutorial
progresses, explanations for each function will be provided. Fill in the
following code in `tutorial_grader.cpp`:

```
#include "framework.h"

void testBringup(lc3::sim & sim) { }

void testTeardown(lc3::sim & sim) { }

void setup(Tester & tester) { }

void shutdown(void) { }
```

To build the unit test, you must first rerun CMake to make it aware of the new
unit test file. Then you may build the unit test. Navigate to the `build/`
directory that was created during the [initial build](BUILD.md) and invoke the
following commands:

```
cmake -DCMAKE_BUILD_TYPE=Release ..
make
```

You should see a new executable at `build/bin/tutorial_grader`. Once the unit
test has been built for the first time, it suffices to just run the `make`
command from the `build/` directory to rebuild.

## Adding a Test Case
A test case takes the form of a function and takes three arguments of the
following types:
1. `lc3::sim &`: A reference to the simulator object that is running the input
   program.
2. `Tester &`: A reference to the unit testing framework.
3. `double`: The total number of points allocated for the test case.

Note that the simulator object is reinitialized between test cases to prevent
contamination.

For the first test case, check if the input program terminates correctly when
there are 0 numbers in the input (i.e. the value at location 0x3200 is 0).

First, define a new function:

```
void ZeroTest(lc3::sim & sim, Tester & tester, double total_points)
{
}
```

Since the simulator is reinitialized for every test case, it is always necessary
to initialize the PC as well as other input values. In this case that means
additionally initializing location 0x3200. Initialize the values by adding the
following code to the `ZeroTest` function:

```
sim.writePC(0x3000);
sim.writeMem(0x3200, 0);
```

The `writePC` function, as expected, sets the PC to location 0x3000. The
`writeMem` function sets the value at memory location 0x3200 (i.e. the first
argument) to 0 (i.e.  the second argument).

Next the test case should actually run the input program so it can verify the
results. It is usually best to restrict the total number of instructions that
are executed so that the grader terminates even if the input program does not.
To be safe, set the instruction limit to 50000 instructions (which will execute
in well under 1 second) and then run the input program. Add the following lines
to the `ZeroTest` function.

```
sim.setRunInstLimit(50000);
sim.run();
```

The `setRunInstLimit` function sets the maximum number of instructions to 50000.
The `run` function will execute the input program until it halts or the
instruction limit is reached.

Finally, verify that the result is correct by adding the following line to the
`ZeroTest` function:

```
tester.verify("Correct", sim.readMem(0x3100) == 0, total_points);
```

The `readMem` function returns the value at location 0x3100.

The `verify` function takes the following three arguments:
1. `std::string`: The message to print in the report for this particular check.
2. `bool`: The condition that must be satisfied to earn points.
3. `double`: The number of points allocated for this particular check.

A single test case may invoke the verify function any number of times and
allocate any amount of points to each check. In this case you just need to check
one thing, the final value in memory location 0x3100, so we assign the full
number of points to the check.

That's it! It only took 5 lines to create a simple test case. The last step is
to make sure the testing framework invokes the test case. To do this, add the
following line to the `setup` function.

```
tester.registerTest("Zero Test", ZeroTest, 100, false);
```

The `setup` function is called one time before any test cases are run. It can
be used to register the test cases as well as initialize any global variables
that the unit test needs to keep track of.

The `registerTest` function informs the testing framework that it should invoke
a test case and takes the following arguments:
1. `std::string`: The name of the test case.
2. `void(lc3::sim &, Tester &, double)`: A pointer to test case.
3. `double`: The total number of points allocated for the test case.
4. `bool`: Whether to randomize the machine before running the test case
   (`true`) or not (`false`).

### Running the Unit Test
Build the unit test by running the `make` command from the `build/` directory.
To run the unit test, simply invoke the `tutorial_grader` executable with
`tutorial_sol.asm` as an argument. This can be done by running the following
command from the root directory:

```
build/bin/tutorial_grader tutorial_sol.asm
```

The output should be as follows:

```
attemping to assemble tutorial_sol.asm into tutorial_sol.obj
assembly successful
==========
Test: Zero Test
  Correct => Pass (+10 pts)
Test points earned: 10/10 (100%)
==========
==========
Total points earned: 10/10 (100%)
```

## Adding Another Test Case
The following test case will test an actual array of numbers:

```
void SimpleTest(lc3::sim & sim, Tester & tester, double total_points)
{
    // Initialize PC and memory locations
    sim.writePC(0x3000);

    uint16_t values[] = {5, 4, 3, 2, 1, 0};
    uint64_t num_values = sizeof(values) / sizeof(uint16_t);
    uint16_t real_sum = 0;

    for(uint64_t i = 0; i < num_values; i += 1) {
        sim.writeMem(0x3200 + static_cast<uint16_t>(i), values[i]);
        real_sum += values[i];
    }

    // Run test case
    sim.setRunInstLimit(50000);
    sim.run();

    // Verify result
    tester.verify("Correct", sim.readMem(0x3100) == real_sum, total_points);
}
```

Also, register the test case to be valued at 20 points by adding the following
line to the `setup` function.

```
tester.registerTest("Simple Test", SimpleTest, 20, false);
```

After rebuilding the grader and running it, you should see the following output:

```
attemping to assemble tutorial_sol.asm into tutorial_sol.obj
assembly successful
==========
Test: Zero Test
  Correct => Pass (+10 pts)
Test points earned: 10/10 (100%)
==========
Test: Simple Test
  Correct => Pass (+20 pts)
Test points earned: 20/20 (100%)
==========
==========
Total points earned: 30/30 (100%)
```

### Refactoring with `testBringup` and `testTeardown`
You may note that setting the PC and the instruction limit are redundant for all
test cases. The `testBringup` and `testTeardown` functions can be used to remove
some redundancy. These functions are run before and after, respectively, each
test case. This is unlike the `setup` function which is run only once before
any test cases (before the first `testBringup`).

To remove some redundancy in the initialization of the test cases, add the
following lines to the `testBringup` function and remove them from the
`ZeroTest` and `SimpleTest` functions:

```
sim.writePC(0x3000);
sim.setRunInstLimit(50000);
```

As an aside, the `shutdown` function is called once after all the test cases
have run (after the last `testTeardown`) and can be used to clean up any global
variables that were initialized in the `setup` function for the unit test to
use.

## Conclusion
The full source code of this tutorial can be found in
[src/test/tests/samples/tutorial_grader.cpp](https://github.com/chiragsakhuja/lc3tools/blob/master/src/test/tests/samples/tutorial_grader.cpp).
This tutorial covered a small subset of the capabilities of the unit testing
framework and API. Some other features include: easy-to-use I/O checks; hooks
before and after instruction execution, subroutine calls, interrupts, etc.; and
control over every element of the LC-3 state. Full details can be found in the
[API document](API.md).

## Appendix: Common Paradigms
Some common paradigms can be found across test cases, such as supplying input
and checking output. The descriptions of each of the functions in this section
can be found in the [API document](API.md).

### Successful Exit Paradigm
There are typically two conditions for a successful exit: the input program does
not trigger any LC-3 exceptions and it does not exceed the instruction limit.
The variants of the `run` functions, detailed in the [API document](API.md),
return a boolean based on the status of execution. If the return value is
`true`, the program did not trigger any exceptions. The `didExceedInstLimit`
function returns whether or not the program exceeded the instruction limit.
Assuming the limit is set to a reasonably high number, exceeding the limit
typically means the program did not halt.

Thus, the following simple check can be added at the end of each test case to
verify the program behaved correctly.

```
bool success = sim.runUntilHalt();
tester.verify("Correct execution", success & ! sim.didExceedInstLimit(), 0);
```

### I/O Paradigm (Polling)
Assume you would like to grade an assignment that prints a prompt, requests
input, does something with the input, then prints the prompt again. This process
repeats until the user types in a response that quits the program. For example,
take a program that repeats the inputted character 5 times:

```
Enter a character (q to exit): a
aaaaa
Enter a character (q to exit): b
bbbbb
Enter a character (q to exit): q
```

A test case could be written using the I/O API, detailed in the [API
document](API.md).

```
bool success = true;

success &= sim.runUntilInputRequested();
tester.checkMatch(tester.getOutput(), "Enter a character (q to exit): ");

tester.clearOutput();
tester.setInputString("a");
success &= sim.runUntilInputRequested();
tester.checkContains(tester.getOutput(), "aaaaa");

tester.clearOutput();
tester.setInputString("b");
success &= sim.runUntilInputRequested();
tester.checkContains(tester.getOutput(), "bbbbb");

tester.setInputString("q");
success &= sim.runUntilHalt();
tester.verify("Correct execution", success && ! sim.didExceedInstLimit(), total_points);
```

The first two lines verify that the prompt is correct, before sending any input.
`runUntilInputRequested` allows the entire prompt to print and then pauses
simulation as soon as any input is requested. Thus, the only output that has
been generated so far will be the prompt.

The next set of lines clears the output buffer, which erases the prompt and any
other output the simulation has created thus far. Then the input can be set.
Finally, the output is checked to see if it contains the duplicated input. This
sequence is checked for the input "a" and "b".

The final set of lines verifies that the program exits properly as described in
the [Successful Exit Paradigm](GRADE.md#successful-exit-paradigm).

**Important Note about I/O**

Remember that the newline character is considered input like any other keys. As
such, you must add a `\n` to the end of the string provided to `setInputString`
function if the program expects a newline character.

### I/O Paradigm (Interrupt)
The I/O Paradigm for interrupt-driven input is similar to the paradigm for
polling, so please read [that section](GRADE.md#io-paradigm-polling) before.

The main difference between interrupt-driven and polling-driven paradigms is
`runUntilInputRequested` can no longer be reliably used since the program will
never request for input. Instead the program must run normally after the input
string has been set.

```
tester.setInputString("a");
tester.setInputCharDelay(50);
bool success = sim.run();
tester.verify("Correct output", tester.checkContains(tester.getOutput(), "aaaaa"), total_points / 2);
tester.verify("Correct execution", success && ! sim.didExceedInstLimit(), total_points / 2);
```

The `setInputCharDelay` delays the input from being sent until 50 instructions
have executed. This is useful in the context of interrupts because interrupts
are disabled by default and the program must execute a handful of instructions
to enable them. Note that `setInputCharDelay` applies to every character, not
the string as a whole, and remains set until it is changed again.

# Additional Resources
The [API document](API.md) contains a comprehensive description of all of the
features that the simulator and testing framework provide. 

Several unit tests are also provided in the `src/test/tests/samples` directory
that can be used as reference. They are practical unit tests developed over the
course of 2 semesters of real assignments at UT Austin. They exemplify testing
features as follows:

1. `binsearch`: complex data initialization; I/O paradigm (polling); simulator
   randomization
2. `interrupt1`: exception checking; I/O paradigm (interrupt); simulator
   randomization
3. `interrupt2`: exception checking; I/O paradigm (interrupt); simulator
   randomization
4. `intersection`: complex data initialization; complex verification; exception
   checking; simulator randomization
5. `nim`: complex I/O interaction; complex verification; exception checking;
   fuzzy string matching; I/O paradigm (polling); simulator randomization;
   string preprocessor
6. `polyroot`: exception checking; simulator hooks; simulator randomization;
    time complexity verification
7. `pow2`: exception checking; simulator randomization
8. `rotate`: detailed report messages; exception checking; simulator
   randomization
9. `shift`: detailed report messages; exception checking; simulator
   randomization
10. `sort`: exception checking; report messages; simulator randomization

A more in-depth description of each assignment can be found in the [Sample
Assignments document](SampleAssignments.pdf).

Assembly/binary solutions for each assignment (other than `nim`) are also
provided in `src/test/tests/samples/solutions`. To verify the unit test's
functionality, you may run the following from the root directory after
[compiling the command line tools](BUILD.md).

```
build/bin/binsearch src/test/tests/samples/solutions/binsearch.asm
build/bin/interrupt1 src/test/tests/samples/solutions/interrupt1.asm
build/bin/interrupt2 src/test/tests/samples/solutions/interrupt2.asm
build/bin/intersection src/test/tests/samples/solutions/intersection.asm
build/bin/polyroot src/test/tests/samples/solutions/polyroot.asm
build/bin/pow2 src/test/tests/samples/solutions/pow2.bin
build/bin/rotate src/test/tests/samples/solutions/rotate.bin
build/bin/shift src/test/tests/samples/solutions/shift.bin
build/bin/sort src/test/tests/samples/solutions/sort.asm
```

# Copyright Notice
Copyright 2020 &copy; McGraw-Hill Education. All rights reserved. No
reproduction or distribution without the prior written consent of McGraw-Hill
Education.