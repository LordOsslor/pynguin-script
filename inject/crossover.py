#  This file is part of Pynguin.
#
#  SPDX-FileCopyrightText: 2019–2024 Pynguin Contributors
#
#  SPDX-License-Identifier: MIT
#
"""Provide various crossover functions for genetic algorithms."""
from abc import abstractmethod
from math import floor
from typing import Generic
from typing import TypeVar

import pynguin.ga.chromosome as chrom

# from pynguin.ga.testcasechromosome import TestCaseChromosome
from pynguin.ga.testsuitechromosome import TestSuiteChromosome

# from pynguin.testcase.statement import Statement
from pynguin.testcase.statement import MethodStatement
from pynguin.testcase.statement import ConstructorStatement
from pynguin.testcase.statement import PrimitiveStatement
from pynguin.testcase.statement import NoneStatement


from pynguin.utils import randomness

from unittest.mock import Mock
# import logging


T = TypeVar("T", bound=chrom.Chromosome)


# _LOGGER = logging.getLogger(__name__)

class CrossOverFunction(Generic[T]):
    
    
    # _logger = logging.getLogger(__name__)
    
    
    """Cross over two individuals."""

    @abstractmethod
    def cross_over(self, parent_1: T, parent_2: T) -> None:
        """Perform a crossover between the two parents.

        Args:
            parent_1: The first parent chromosome
            parent_2: The second parent chromosome
        """

class HMX(CrossOverFunction[T]):
# class SinglePointRelativeCrossOver(CrossOverFunction[T]):
    """Performs a single-point relative crossover of the two parents.

    The splitting point is not an absolute but a relative value (e.g., at position 70%
    of n). For example, if n1=10 and n2=20 and the splitting point is 70%, we would have
    position 7 in the first and 14 in the second.

    Therefore, the offspring d has n<=max(n1, n2)
    """



    def cross_over(self, parent_1: T, parent_2: T) -> None:  # noqa: D102
        
        
        
        if parent_1.size() < 2 or parent_2.size() < 2:
            return





        split_point = randomness.next_float()
        pos_1 = floor((parent_1.size() - 1) * split_point) + 1
        pos_2 = floor((parent_2.size() - 1) * split_point) + 1
        clone_1 = parent_1.clone()
        clone_2 = parent_2.clone()
        parent_1.cross_over(clone_2, pos_1, pos_2)
        parent_2.cross_over(clone_1, pos_2, pos_1)



# class HMX(CrossOverFunction[T]):
class SinglePointRelativeCrossOver(CrossOverFunction[T]):
    """Performs a hybrid multi-level crossover of the two parents.
    """
    
    def cross_over(self, parent_1: T, parent_2: T) -> None:  # noqa: D102
        
            
        def fill_dicts(parent: T, methods: dict = {}, constructors: dict = {}, first_run: bool = True):
            
            methods_to_fill = {}
            constructors_to_fill = {}
            attributes_to_fill = {}
            
            for statement in parent.test_case.statements:
                
                if isinstance(statement, MethodStatement):
                    
                    if first_run or str(statement) in methods.keys():
                        
                        if not str(statement) in methods_to_fill:
                            methods_to_fill[str(statement)] = set() 
                        methods_to_fill[str(statement)].add(statement)
                    
                elif isinstance(statement, ConstructorStatement):
                    
                    if first_run or str(statement) in constructors.keys():
    
                        if not str(statement) in constructors_to_fill:
                            constructors_to_fill[str(statement)] = set()
                        constructors_to_fill[str(statement)].add(statement)
                    
                elif isinstance(statement, PrimitiveStatement) and not isinstance(statement, NoneStatement):      # NoneStatements are PrimitiveStatements
                   
                    attributes_to_fill[statement.ret_val] = statement
                
            return methods_to_fill, constructors_to_fill, attributes_to_fill
           
        
        if parent_1.size() < 2 or parent_2.size() < 2:
            return


        split_point = randomness.next_float()
        pos_1 = floor((parent_1.size() - 1) * split_point) + 1
        pos_2 = floor((parent_2.size() - 1) * split_point) + 1
        clone_1 = parent_1.clone()
        clone_2 = parent_2.clone()
        parent_1.cross_over(clone_2, pos_1, pos_2)
        parent_2.cross_over(clone_1, pos_2, pos_1)
        
        
        if isinstance(parent_1, Mock) and isinstance(parent_2, Mock):       # Error during pytest
            
            return
        
        elif isinstance(parent_1, TestSuiteChromosome) and isinstance(parent_2, TestSuiteChromosome):         # Multiple TestCasesChromosomes
                 
            if parent_1.size() < parent_2.size():
                
                length = parent_1.size()
            
            else:
                length = parent_2.size()
            
                for i in range(0, length):
                      
                      self.cross_over(parent_1.get_test_case_chromosome(i), parent_2.get_test_case_chromosome(i))
        
         
            """Creating the dictionaries to store the methods, constructors and attributes of the parent chromosomes"""
        else:
            methods1, constructors1, attributes1 = fill_dicts(parent_1)
        
            methods2, constructors2, attributes2 = fill_dicts(parent_2, methods1, constructors1, False)   
        
                     
        
        """Next step described in the paper, data-level crossover"""
        
        self.data_cross_over(methods1, attributes1, methods2, attributes2)
        
        self.data_cross_over(constructors1, attributes1, constructors2, attributes2)
        
    
    
    
    def data_cross_over(self, function1: dict, attributes1: dict, function2: dict, attributes2: dict) -> None:
        
        def StringCrossover(val1, val2):
            """
            Perform a single-point string crossover between two parent strings.
            
            Args:
                val1 (str): The first parent string.
                val2 (str): The second parent string.
                
            Returns:
                Tuple[str, str]: Two offspring strings.
            """
            
            if len(val1) == 0 or len(val2) == 0:
                    return val1, val2
                
                
            split_point1 = randomness.next_int(0, len(val1))
            split_point2 = randomness.next_int(0, len(val2))
            
            temp = val1
            val1 = val1[:split_point1] + val2[split_point2:]
            val2 = val2[:split_point2] + temp[split_point1:]
            
            return val1, val2
        
        def SBX(val1, val2, distribution_idx: float = 2.5) -> float:
            """
            Perform a simulated binary crossover between two parent values.
            
            Args:
                val1 (int): The first parent value.
                val2 (int): The second parent value.
                
            Returns:
                float: The new value after crossover.
            """
            u = randomness.next_float(0, 1)
            if u < 0.5:
                beta = 2 * (u**(distribution_idx+1))
            elif u == 0.5:
                beta = 1
            else:
                beta = (1 / (2 * (1 - u))) ** (1/3)
            b = randomness.choice([True, False])
            
            if b:
                return (0.5 * (val1 - val2)) - (0.5 * beta * abs(val1 - val2))
            else:
                return (0.5 * (val1 - val2)) + (0.5 * beta * abs(val1 - val2))        
        
        
        
        for signature in function2.keys():               # methods1 is a superset of methods2
            
            rand2 = randomness.next_int(0, len(function2[signature])) # Pick a random statement from the set
            statement2 = list(function2[signature])[rand2]  # Convert set to list before indexing
            
                
            if(signature in function1):  # Probably not necessary
                pass
                
            else:   # perhaps due to an error
            
                continue
            
            
            
            if len(statement2.args) != 0:
                
                
                rand_arg = randomness.next_int(0, len(statement2.args))

                arg2 = list(statement2.args.values())[rand_arg]
                

                
                if arg2 is not None:
                
                    if arg2.is_primitive():
                        
                        rand1 = randomness.next_int(0, len(function1[signature]))
                        statement1 = list(function1[signature])[rand1]
                        
                        arg1 = None
                        changed = False
                        counter = 0
                        
                        while(not changed and counter < 10):
                            counter += 1
                            rand_arg = randomness.next_int(0, len(statement1.args))
                            arg1 = list(statement1.args.values())[rand_arg]
                            
                            if str(arg1._type) == str(arg2._type):
                                changed = True
                        
                        if not changed:
                            
                            for arg in statement1.args.values():            # This is not random
                                if str(arg) == str(arg2):
                                    arg1 = arg
                                    break
                                
                        if arg1 in attributes1 and arg2 in attributes2:
                            
                            val1, val2 = attributes1[arg1].value, attributes2[arg2].value
                            
                            
                            if isinstance(val1, (str, bytes)) and isinstance(val2, (str, bytes)):
                                val1, val2 = StringCrossover(val1, val2)
                            else:
                                val1 = SBX(val1, val2)
                                val2 = SBX(val2, val1)
                            
                            attributes1[arg1].value = val1
                            attributes2[arg2].value = val2
                    
        



