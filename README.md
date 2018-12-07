# Asynchronous-Gossip-and-Push-Sum

## Goal
Determine the most optimum network for group communication and aggregate communication.
* Gossip: Find the amount of time taken for every node to recieve a message, starting from one node with multiple network topologies and draw a graph to depict this.
* Push-Sum: Find the amount of time taken to find the closest approximation to the sum of all the values in the nodes with multiple network topoliges and draw a graph to depict this.

## Group members

* Prahlad Misra [UFID: 00489999]
* Saranya Vatti [UFID: 29842706]

## Instructions

* Project was developed and tested in windows 8; 4 core
* Unzip Prahlad_Saranya.zip 

```sh
> unzip prahlad_saranya.zip
> cd prahlad_saranya
>  mix run proj2.exs 10 full gossip
Updating node number as per topology. New node count : 10
1 out of 500 have stopped transmitting
2 out of 500 have stopped transmitting
3 out of 500 have stopped transmitting
.
.
.
449 out of 500 have stopped transmitting
450 out of 500 have stopped transmitting
It took 3840000 milliseconds to converge

>mix run proj2.exs 10 imp2D push-sum
Updating node number as per topology. New node count : 10
10
1 converged with ratio 9.999999999999998
4 converged with ratio 10.6111437692094
5 converged with ratio 10.609228160401218
8 converged with ratio 10.619163526390347
2 converged with ratio 10.61719367508708
9 converged with ratio 10.608361529138506
3 converged with ratio 10.610224128591607
7 converged with ratio 10.619538671374942
It took 159744 milliseconds to converge to ratio 10.619538671374942
```

## About Gossip

* A Supervisor process is first created and it parses the inputs
* According to the inputs, it created the number of nodes specified. In case of topologies like 3D and Sphere, the number of nodes are rounded up to the closest cube and square respectively
* The Supervisor picks a random process and propogates the message.
* Each node then transmits the message to other node (picked by topology), and also calls itself to ensure continuous propogation
* The state of the GenServer worker takes care of the number of times it recieves the message. Once it crosses a threshold of max_count, it stops transmitting and sends a message to the Supervisor to increment the count of nodes completely heard.
* The Supervisor keeps listening for the nodes who have heard the message. Once 90% or more coverage is done, the Supervisor dies.
* The time taken is measure from the creation of nodes to the ending of the Supervisor

## Observations

* While "Full" topology converges faster with 100% convergence, "line" topology converges faster with 90% convergence. This is when the nodes are not killed or taken off the process list but keep recieving messages but just stop transmitting.
* Overall, "Full" topology is fast and is easier to implement in smaller networks but may be cumbersome to implement in a large network since every child process needs to have a record of the other pid
* Convergence criteria for Gossip is assumed to be when 90% of the nodes have recieved the message some max (50) number of times. Increasing this number increased the time taken to converge as expected.

## Time taken to achieve convergence for Gossip is tabulated below.

Times are measured with System.monotonic_time before the process starts and after convergence of 90% or more is achieved.
Times are checked for a convergence of 50 times (once a worker recieves message 50 times, it stops transmitting)
Assuming 90% and 100% convergence.

| Number of Nodes  |     Full      |     Line      | Imperfect Line |     3D        |     Sphere    |Random 2D Grid |
| ---------------- |:-------------:|:-------------:|:--------------:|:-------------:|:-------------:|:-------------:|
|      100         |    272384     |    1664000    |    1452384     |    191488     |    47104      |    31744      |
|      200         |    400384     |    2816000    |    3068256     |    400384     |    303104     |    128000     |
|      300         |    384000     |    4175872    |    3940384     |    671744     |    527360     |    240640     |
|      500         |    543744     |    7312384    |    6504512     |    799744     |    655360     |    896000     |
|     1000         |    751616     |    14464000   |   13524384     |    1391616    |    1392640    |    3152896    |
|     2000         |    960512     |    27791360   |   25360640     |    2511872    |    1375232    |    17551360   |
|     5000         |   1536000     |    95072256   |   55600128     |    6416384    |    6335488    |    28383232   |
|     7000         |   1808384     |   160751616   |  110751616     |    6863872    |    14783488   |    53312512   |
|     10000        |   2112512     |               |                |    13024256   |    13680640   |               |
|     15000        |   2656256     |               |                |    21263360   |    20960256   |               |
|     20000        |   2927616     |               |                |               |               |               |
|     25000        |   3424256     |               |                |               |               |               |
|     50000        |   6448128     |               |                |               |               |               |
|     75000        |  12832768     |               |                |               |               |               |
|    100000        |  19823616     |               |                |               |               |               |
|    150000        |  43904000     |               |                |               |               |               |
|    200000        |  85791744     |               |                |               |               |               |



## Time taken to achieve convergence for Push-Sum is tabulated below.

Times are measured with System.monotonic_time before the process starts. 

| Number of Nodes  |     Full      |     Line      | Imperfect Line |     Sphere    |     3D        |Random 2D Grid |
| ---------------- |:-------------:|:-------------:|:--------------:|:-------------:|:-------------:|:-------------:|
|      10          |     31744     |    1935360    |    159744      |    47104      |     607232    |      32104    |
|      20          |     48128     |    319488     |    1024000     |    1664000    |     607232    |    1454000    |
|      30          |     31744     |    2432000    |    2800640     |    5359616    |    1024000    |    5844616    |
|      50          |     111616    |    1024000    |    12608512    |    37727232   |    76512512   |    3734232    |
|      70          |     223232    |    6095872    |    57136128    |    10384384   |    93519872   |    10764384   |


## What is working

### Topologies:

* full -Every actor is a neighbour of all other actors. That is, every actor can talk directly to any other actor.
* 3D - Actors form a 3D grid. The actors can only talk to the grid neigbors.
* rand2D - Random 2D Grid: Actors are randomly position at x,y coordinnates on a [0-1.0]X[0-1.0] square. Two actors are connected if they are within .1 distance to other actors.
* sphere - Actors are arranged in a sphere. That is, each actor has 4 neighbors (similar to the 2D grid) but both directions are closed to form circles
* line - Actors are arranged in a line. Each actor has only 2 neighboors (one left and one right, unless you are the rst or last actor)
* imp2D - Imperfect Line: Line arrangement but one random other neighboor is selected from the list of all actors.

* Complete convergence is achieved on both algorithms for all topologies 

## What is the largest network you managed to deal with for each type of topology and algorithm

|                  |       Gossip     |      Push Sum    |  
| ---------------- | ---------------- | ---------------- |
|      Full        |       15000      |      400         |
|      Line        |        7000      |      100         |
|  Imperfect2D     |        7000      |      300         |
|     Sphere       |       15000      |      200         |
|     3D           |       15000      |      100         |
| Random 2D Grid   |        7000      |      200         |


Times are measures as per System.monotonic_time()
